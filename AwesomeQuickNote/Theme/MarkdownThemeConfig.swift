import MarkdownUI
import SwiftUI

extension MarkdownUI.Theme {
    static let monokai = MarkdownUI.Theme()
        .text {
            ForegroundColor(Monokai.foreground)
            FontSize(14)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(24)
                    ForegroundColor(Monokai.keyword)
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(20)
                    ForegroundColor(Monokai.keyword)
                }
                .markdownMargin(top: 14, bottom: 6)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(17)
                    ForegroundColor(Monokai.keyword)
                }
                .markdownMargin(top: 12, bottom: 4)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(15)
                    ForegroundColor(Monokai.keyword)
                }
                .markdownMargin(top: 10, bottom: 4)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(14)
                    ForegroundColor(Monokai.keyword)
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(13)
                    ForegroundColor(Monokai.keyword)
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(13)
            ForegroundColor(Monokai.string)
            BackgroundColor(Color(hex: 0x3E3D32))
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(13)
                    ForegroundColor(Monokai.foreground)
                }
                .padding(12)
                .background(Color(hex: 0x1E1F1C))
                .clipShape(.rect(cornerRadius: 6))
                .markdownMargin(top: 8, bottom: 8)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Monokai.comment)
                    .frame(width: 3)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(Monokai.comment)
                        FontStyle(.italic)
                    }
                    .padding(.leading, 12)
            }
            .markdownMargin(top: 8, bottom: 8)
        }
        .link {
            ForegroundColor(Monokai.type)
        }
        .strong {
            FontWeight(.bold)
            ForegroundColor(Monokai.function)
        }
        .emphasis {
            FontStyle(.italic)
            ForegroundColor(Monokai.foreground)
        }
        .strikethrough {
            StrikethroughStyle(.single)
            ForegroundColor(Monokai.comment)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
        .taskListMarker { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isCompleted ? Monokai.function : Monokai.comment)
                .font(.system(size: 14))
        }
}
