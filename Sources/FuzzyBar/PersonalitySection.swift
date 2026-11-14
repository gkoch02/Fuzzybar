import SwiftUI
import UniformTypeIdentifiers

/// A personality in the picker: one of ours, or one imported from a file.
enum PersonalityChoice: Hashable {
    case builtIn(Personality)
    case custom(UUID)
}

/// Preferences' personality picker, with importing and saving templates.
struct PersonalitySection: View {
    @EnvironmentObject private var personalities: PersonalityStore
    @Binding var message: PersonalityMessage?
    @State private var importing = false
    @State private var exporting = false

    private var choice: Binding<PersonalityChoice> {
        Binding(
            get: { personalities.customPersonalityID.map(PersonalityChoice.custom) ?? .builtIn(personalities.personality) },
            set: { new in
                message = nil
                switch new {
                case let .builtIn(personality):
                    personalities.customPersonalityID = nil
                    personalities.personality = personality
                case let .custom(id):
                    personalities.customPersonalityID = id
                }
            }
        )
    }

    /// The active personality as a file to start from. One with no slot
    /// table hands out Classic's instead.
    private var template: CustomPersonality {
        personalities.activeCustom ?? personalities.personality.template ?? Personality.classic.template!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Personality", selection: choice) {
                ForEach(Personality.allCases) { Text($0.title).tag(PersonalityChoice.builtIn($0)) }
                if !personalities.customPersonalities.isEmpty {
                    Divider()
                    ForEach(personalities.customPersonalities) { Text($0.name).tag(PersonalityChoice.custom($0.id)) }
                }
            }
            Text(personalities.activeCustom == nil ? personalities.personality.note : "Your own, imported from a file.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(personalities.phrase(hour: 20, minute: 40))
                .font(.callout.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                .accessibilityLabel("Example at 8:40 pm")
            HStack {
                Button("Import…") { importing = true }
                Button("Save as Template…") { exporting = true }
                Spacer(minLength: 0)
                if let custom = personalities.activeCustom {
                    Button("Remove") {
                        personalities.removePersonality(id: custom.id)
                        message = PersonalityMessage(text: "Removed \(custom.name).")
                    }
                }
            }
            .controlSize(.small)
            if let message {
                Text(message.text)
                    .font(.caption).foregroundStyle(message.isError ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fileImporter(isPresented: $importing, allowedContentTypes: [CustomPersonality.contentType, .plainText]) { result in
            switch result {
            case let .success(url): message = personalities.importPersonality(from: url)
            case let .failure(error): message = PersonalityMessage(text: error.localizedDescription, isError: true)
            }
        }
        .fileExporter(isPresented: $exporting, document: PersonalityFile(data: template.encoded()),
                      contentType: CustomPersonality.contentType, defaultFilename: template.name) { result in
            switch result {
            case let .success(url):
                // Straight into the text editor: save, edit, import.
                NSWorkspace.shared.open(url)
                message = PersonalityMessage(text: "Saved and opened in your text editor. Change the words, save, then import it.")
            case let .failure(error):
                message = PersonalityMessage(text: error.localizedDescription, isError: true)
            }
        }
    }
}

/// A .fuzzybar file for the save panel.
struct PersonalityFile: FileDocument {
    static let readableContentTypes = [CustomPersonality.contentType]
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
