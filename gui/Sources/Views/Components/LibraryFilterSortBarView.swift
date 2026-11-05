import SwiftUI
import AppKit

public struct LibraryFilterSortBarView: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            Spacer()
            
            // Search Field Capsule (positioned on the right next to filters)
            NXLiquidGlassSearchField(
                viewModel.tr("library.search_placeholder"),
                text: $viewModel.librarySearchText
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: 220)
            .nxGlassBar(
                in: Capsule(),
                fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.85),
                fallbackStroke: NXTheme.borderSubtle
            )
            
            // Group Filter Menu
            Menu {
                ForEach(LibraryGroupFilter.allCases) { filter in
                    Button {
                        SoundEffectService.shared.play(.click)
                        viewModel.activeGroupFilter = filter
                        viewModel.reconcileLibraryFocusState()
                    } label: {
                        HStack {
                            Image(systemName: filter.iconName)
                            Text(viewModel.tr(filter.translationKey))
                            if viewModel.activeGroupFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.activeGroupFilter.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(NXTheme.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(NXTheme.textSecondary.opacity(0.85))
                }
                .padding(.horizontal, 7)
                .frame(height: 26)
                .nxGlassBar(
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous),
                    fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.70),
                    fallbackStroke: NXTheme.borderSubtle
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .nxNoFocusRing()
            .help(viewModel.tr("library.tooltip_filter", viewModel.tr(viewModel.activeGroupFilter.translationKey)))
            
            // Sort Option Menu
            Menu {
                ForEach(LibrarySortOption.allCases) { option in
                    Button {
                        SoundEffectService.shared.play(.click)
                        viewModel.activeSortOption = option
                        viewModel.reconcileLibraryFocusState()
                    } label: {
                        HStack {
                            Image(systemName: option.iconName)
                            Text(viewModel.tr(option.translationKey))
                            if viewModel.activeSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.activeSortOption.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(NXTheme.secondary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(NXTheme.textSecondary.opacity(0.85))
                }
                .padding(.horizontal, 7)
                .frame(height: 26)
                .nxGlassBar(
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous),
                    fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.70),
                    fallbackStroke: NXTheme.borderSubtle
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .nxNoFocusRing()
            .help(viewModel.tr("library.tooltip_sort", viewModel.tr(viewModel.activeSortOption.translationKey)))
            
            // Rescan / Refresh Library Button
            Button {
                SoundEffectService.shared.play(.click)
                viewModel.scanAllGameFolders()
                viewModel.refreshLibrary()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(NXTheme.textPrimary)
                }
                .padding(.horizontal, 7)
                .frame(height: 26)
                .nxGlassBar(
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous),
                    fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.70),
                    fallbackStroke: NXTheme.borderSubtle
                )
            }
            .buttonStyle(PlainButtonStyle())
            .fixedSize()
            .nxNoFocusRing()
            .help(viewModel.tr("library.rescan_tooltip"))
        }
        .padding(.horizontal, 34)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }
}
