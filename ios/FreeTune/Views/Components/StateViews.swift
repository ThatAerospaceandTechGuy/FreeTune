import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.ftRounded(19, weight: .bold))
                .foregroundColor(.ftText)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.ftPrimary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .light))
                .foregroundColor(.ftSecondaryText)
            Text(title)
                .font(.ftRounded(18, weight: .semibold))
                .foregroundColor(.ftText)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.ftSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
    }
}

struct ErrorCard: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.ftError)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.ftText)
                    .fixedSize(horizontal: false, vertical: true)
                if let retry {
                    Button("Try again", action: retry)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.ftPrimary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ftError.opacity(0.12))
        )
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(selected ? .ftOnPrimary : .ftText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(selected ? Color.ftPrimary : Color.ftSurfaceVariant)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SmallActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.ftPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.ftPrimary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

struct DownloadProgressRow: View {
    let status: DownloadStatus

    private var detail: String {
        if status.state == .queued {
            return status.message ?? "Queued"
        }
        if status.progress <= 0 {
            return status.message ?? "Starting…"
        }
        return "\(Int((status.progress * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(status.track.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.ftText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.ftSecondaryText)
                    .lineLimit(1)
            }
            ProgressView(value: status.progress)
                .tint(.ftPrimary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ftSurfaceVariant)
        )
    }
}

struct FailedDownloadRow: View {
    let status: DownloadStatus
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(status.track.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.ftText)
                    .lineLimit(1)
                Text(status.message ?? "Download failed")
                    .font(.caption)
                    .foregroundColor(.ftSecondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button("Retry", action: onRetry)
                .font(.caption.weight(.semibold))
                .foregroundColor(.ftPrimary)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.ftSecondaryText)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ftError.opacity(0.10))
        )
    }
}
