// The MIT License
//
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
import Foundation

extension StandardLibrary {

    /**
    StandardLibrary.Localizer provides localization of Mustache sections or
    data.

        let localizer = StandardLibrary.Localizer(bundle: nil, table: nil)
        template.registerInBaseContext("localize", Box(localizer))

    ### Localizing data:

    `{{ localize(greeting) }}` renders `NSLocalizedString(@"Hello", nil)`,
    assuming the `greeting` key resolves to the `Hello` string.

    ### Localizing sections:

    `{{#localize}}Hello{{/localize}}` renders `NSLocalizedString(@"Hello", nil)`.

    ### Localizing sections with arguments:

    `{{#localize}}Hello {{name}}{{/localize}}` builds the format string
    `Hello %@`, localizes it with NSLocalizedString, and finally
    injects the name with `String(format:...)`.

    ### Localize sections with arguments and conditions:

    `{{#localize}}Good morning {{#title}}{{title}}{{/title}} {{name}}{{/localize}}`
    build the format string `Good morning %@" or @"Good morning %@ %@`,
    depending on the presence of the `title` key. It then injects the name, or
    both title and name, with `String(format:...)`, to build the final
    rendering.
    */
    public final class Localizer : MustacheBoxable {
        /// The bundle
        public let bundle: Bundle

        /// The table
        public let table: String?

        /**
        Returns a Localizer.

        - parameter bundle: The bundle where to look for localized strings. If
                            nil, the main bundle is used.
        - parameter table:  The table where to look for localized strings. If
                            nil, the default `Localizable.strings` is used.
        - returns: A new Localizer.
        */
        public init(bundle: Bundle?, table: String?) {
            self.bundle = bundle ?? Bundle.main
            self.table = table
        }

        /**
        `Localizer` adopts the `MustacheBoxable` protocol so that it can feed
        Mustache templates.

        You should not directly call the `mustacheBox` property. Always use the
        `Box()` function instead:

            localizer.mustacheBox   // Valid, but discouraged
            Box(localizer)          // Preferred
        */
        public var mustacheBox: MustacheBox {
            // Return a multi-facetted box, because Localizer interacts in
            // various ways with Mustache rendering.
            return MustacheBox(
                // It has a value
                value: self,

                // Localizer can be used as a filter: {{ localize(x) }}:
                filter: Filter(self.filter),

                // Localizer performs custom rendering, so that it can localize
                // the sections it is attached to: {{# localize }}Hello{{/ localize }}.
                render: self.render,

                // Localizer needs to observe the rendering of variables tags
                // inside the section it is attached to: {{# localize }}Hello {{ name }}{{/ localize }}.
                willRender: self.willRender,
                didRender: self.didRender)
        }


        // =====================================================================
        // MARK: - Not public

        private var formatArguments: [String]?

        // This function is used for evaluating `localize(x)` expressions.
        private func filter(rendering: Rendering) throws -> Rendering {
            return Rendering(localizedString(forKey: rendering.string), rendering.contentType)
        }

        // This functionis used to render a {{# localize }}Hello{{/ localize }} section.
        private func render(info: RenderingInfo) throws -> Rendering {

            // Perform a first rendering of the section tag, that will turn
            // variable tags into a custom placeholder.
            //
            // "...{{name}}..." will get turned into "...GRMustacheLocalizerValuePlaceholder...".
            //
            // For that, we make sure we are notified of tag rendering, so that
            // our willRender(tag: Tag, box:) method has the tags render
            // GRMustacheLocalizerValuePlaceholder instead of the regular values.
            //
            // This behavior of willRender() is trigerred by the nil value of
            // self.formatArguments:

            formatArguments = nil


            // Push self in the context stack in order to trigger our
            // willRender() method.

            let context = info.context.extendedContext(by: Box(self))


            let localizableFormatRendering = try info.tag.render(with: context)

            // Now perform a second rendering that will fill our
            // formatArguments array with HTML-escaped tag renderings.
            //
            // Now our willRender() method will let the tags render regular
            // values. Our didRender() method will grab those renderings,
            // and fill self.formatArguments.
            //
            // This behavior of willRender() is not the same as the previous
            // one, and is trigerred by the non-nil value of
            // self.formatArguments:

            formatArguments = []


            // Render again

            try! info.tag.render(with: context)


            let rendering: Rendering
            if formatArguments!.isEmpty
            {
                // There is no format argument, which means no inner
                // variable tag: {{# localize }}plain text{{/ localize }}
                rendering = Rendering(localizedString(forKey: localizableFormatRendering.string), localizableFormatRendering.contentType)
            }
            else
            {
                // There are format arguments, which means inner variable
                // tags: {{# localize }}...{{ name }}...{{/ localize }}.
                //
                // Take special precaution with the "%" character:
                //
                // When rendering {{#localize}}%d {{name}}{{/localize}},
                // the localizable format we need is "%%d %@".
                //
                // Yet the localizable format we have built so far is
                // "%d GRMustacheLocalizerValuePlaceholder".
                //
                // In order to get an actual format string, we have to:
                // - turn GRMustacheLocalizerValuePlaceholder into %@
                // - escape % into %%.
                //
                // The format string will then be "%%d %@", as needed.

                let localizableFormat = localizableFormatRendering.string.replacingOccurrences(of: "%", with: "%%").replacingOccurrences(of: Placeholder.string, with: "%@")

                // Now localize the format
                let localizedFormat = localizedString(forKey: localizableFormat)

                // Apply arguments
                let localizedRendering = string(withFormat: localizedFormat, argumentsArray: formatArguments!)

                // And we have the final rendering
                rendering = Rendering(localizedRendering, localizableFormatRendering.contentType)
            }


            // Clean up

            formatArguments = nil


            // Done

            return rendering
        }

        private func willRender(tag: Tag, box: MustacheBox) -> MustacheBox {
            switch tag.type {
            case .Variable:
                // {{ value }}
                //
                // We behave as stated in the documentation of render():

                if formatArguments == nil {
                    return Box(Placeholder.string)
                } else {
                    return box
                }

            case .Section:
                // {{# value }}
                // {{^ value }}
                //
                // We do not want to mess with Mustache handling of boolean and
                // loop sections such as {{#true}}...{{/}}.
                return box
            }
        }

        private func didRender(tag: Tag, box: MustacheBox, string: String?) {
            switch tag.type {
            case .Variable:
                // {{ value }}
                //
                // We behave as stated in the documentation of render():

                if formatArguments != nil {
                    if let string = string {
                        formatArguments!.append(string)
                    }
                }

            case .Section:
                // {{# value }}
                // {{^ value }}
                break
            }
        }

        private func localizedString(forKey key: String) -> String {
            return bundle.localizedString(forKey: key, value:"", table:table)
        }

        private func string(withFormat format: String, argumentsArray args:[String]) -> String {
            #if os(Linux) // see issue https://bugs.swift.org/browse/SR-957
                // before the issue is resolved - manually replace %@ string one by one by NSLocalizedString
                //TODO remove this ifdef once the feature is implemented
                if args.count == 0 {
                    return format
                }
                fatalError("GRMustache.swift, Localizer.swift:\(#line) Not implemented: String(format, locale, args)")
            #else
            let nsargs = args.map({$0 as NSString})
            switch nsargs.count {
            case 0:
                return String(format: format)
            case 1:
                return String(format: format, nsargs[0])
            case 2:
                return String(format: format, nsargs[0], nsargs[1])
            case 3:
                return String(format: format, nsargs[0], nsargs[1], nsargs[2])
            case 4:
                return String(format: format, nsargs[0], nsargs[1], nsargs[2], nsargs[3])
            case 5:
                return String(format: format, nsargs[0], nsargs[1], nsargs[2], nsargs[3], nsargs[4])
            case 6:
                return String(format: format, nsargs[0], nsargs[1], nsargs[2], nsargs[3], nsargs[4], nsargs[5])
            case 7:
                return String(format: format, nsargs[0], nsargs[1], nsargs[2], nsargs[3], nsargs[4], nsargs[5], nsargs[6])
            case 8:
                return String(format: format, nsargs[0], nsargs[1], nsargs[2], nsargs[3], nsargs[4], nsargs[5], nsargs[6], nsargs[7])
            case 9:
                return String(format: format, nsargs[0], nsargs[1], nsargs[2], nsargs[3], nsargs[4], nsargs[5], nsargs[6], nsargs[7], nsargs[8])
            case 10:
                return String(format: format, nsargs[0], nsargs[1], nsargs[2], nsargs[3], nsargs[4], nsargs[5], nsargs[6], nsargs[7], nsargs[8], nsargs[9])
            default:
                fatalError("Not implemented: format with \(nsargs.count) parameters")
            }
            #endif
        }

        struct Placeholder {
            static let string = "GRMustacheLocalizerValuePlaceholder"
        }
    }

}
