//
//  ServerImage.swift
//  Marlin Media TV
//
//  Artwork the server hands out as server-relative paths, resolved against the base URL. The
//  frames' placeholder (a gradient tile with the title's initial) shows while loading, when
//  there is no artwork, and when the load fails.
//

import SwiftUI

struct ServerImage<Fallback: View>: View {
    let path: String?
    var contentMode: ContentMode = .fill
    @ViewBuilder let fallback: () -> Fallback

    var body: some View {
        if let url = ServerConfig.resolve(path) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    Color.clear
                        .overlay { image.resizable().aspectRatio(contentMode: contentMode) }
                        .clipped()
                } else {
                    fallback()
                }
            }
        } else {
            fallback()
        }
    }
}

/// The frames' poster placeholder: the 155° gradient with the title's initial at 7 % opacity.
struct InitialTile: View {
    let title: String
    var fontSize: CGFloat = 104

    var body: some View {
        Nocturne.posterPlaceholder
            .overlay {
                Text(String(title.prefix(1)))
                    .font(.nocturne(fontSize, .medium))
                    .foregroundStyle(Nocturne.text.opacity(0.07))
            }
    }
}
