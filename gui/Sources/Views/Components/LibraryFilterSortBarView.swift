import SwiftUI
import AppKit

public struct LibraryFilterSortBarView: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Spacer()
            
            // Group Filter Icon-Only Compact Menu
            Menu {
                ForEach(LibraryGroupFilter.allCases) { filter in
                    Button {
                        SoundEffectService.shared.play(.click)
                        withAnimation(.easeInOut(duration: 0.20)) {
                            viewModel.activeGroupFilter = filter
                        }
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
                Image(systemName: viewModel.activeGroupFilter.iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(NXTheme.primary)
                    .frame(width: 28, height: 26)
                    .nxGlassBar(
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous),
                        fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.70),
                        fallbackStroke: NXTheme.borderSubtle
                    )
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 28, height: 26)
            .fixedSize()
            .nxNoFocusRing()
            .help(viewModel.tr("library.tooltip_filter", viewModel.tr(viewModel.activeGroupFilter.translationKey)))
            
            // Sort Option Icon-Only Compact Menu
            Menu {
                ForEach(LibrarySortOption.allCases) { option in
                    Button {
                        SoundEffectService.shared.play(.click)
                        withAnimation(.easeInOut(duration: 0.20)) {
                            viewModel.activeSortOption = option
                        }
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
                Image(systemName: viewModel.activeSortOption.iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(NXTheme.secondary)
                    .frame(width: 28, height: 26)
                    .nxGlassBar(
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous),
                        fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.70),
                        fallbackStroke: NXTheme.borderSubtle
                    )
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 28, height: 26)
            .fixedSize()
            .nxNoFocusRing()
            .help(viewModel.tr("library.tooltip_sort", viewModel.tr(viewModel.activeSortOption.translationKey)))
        }
        .padding(.horizontal, 34)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }
}
