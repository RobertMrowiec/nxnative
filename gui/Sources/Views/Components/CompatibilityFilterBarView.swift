import SwiftUI

public struct CompatibilityFilterBarView: View {
    @ObservedObject public var viewModel: AppViewModel
    @Namespace private var alphaFilterNamespace
    
    private let alphabet = (65...90).map { String(UnicodeScalar($0)) }
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private var hasActiveFilter: Bool {
        viewModel.compatibilityRamFilter != nil ||
        viewModel.compatibilityChipFilter != nil ||
        viewModel.compatibilityGenerationFilter != .all ||
        viewModel.compatibilityOnlyMyDevice ||
        viewModel.compatibilityNameFilter != "All"
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Row 1: Dropdown Hardware Filters (Mac RAM + iPhone Chip Tier + My Device)
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    NXGlassContainer(spacing: 8) {
                        HStack(spacing: 12) {
                            ramDropdownMenu
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 1, height: 18)
                            
                            chipDropdownMenu
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 1, height: 18)
                            
                            myDeviceButton

                            if hasActiveFilter {
                                resetButton
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 3)
                        .frame(minWidth: geo.size.width, alignment: .center)
                    }
                }
            }
            .frame(height: 30)
            
            // Row 2: Centered [New | All (Switch 1/2) | A-Z] Filter Buttons (Single persistent sliding Liquid Glass droplet)
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    NXGlassContainer(spacing: 4) {
                        HStack(spacing: 3) {
                            nameLetterButton(
                                viewModel.tr("compatibility.new"),
                                icon: "sparkles",
                                filterKey: "New",
                                isSelected: viewModel.compatibilityNameFilter == "New"
                            ) {
                                viewModel.compatibilityNameFilter = "New"
                            }
                            
                            allGenerationDropdownMenu
                            
                            ForEach(alphabet, id: \.self) { letter in
                                nameLetterButton(letter, filterKey: letter, isSelected: viewModel.compatibilityNameFilter == letter) {
                                    viewModel.compatibilityNameFilter = letter
                                }
                            }
                        }
                        .background {
                            NXLiquidSlidingPill(in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .matchedGeometryEffect(
                                    id: viewModel.compatibilityNameFilter,
                                    in: alphaFilterNamespace,
                                    properties: .frame,
                                    anchor: .center,
                                    isSource: false
                                )
                                .animation(.spring(response: 0.32, dampingFraction: 0.76), value: viewModel.compatibilityNameFilter)
                        }
                        .padding(.horizontal, 16)
                        .frame(minWidth: geo.size.width, alignment: .center)
                    }
                }
            }
            .frame(height: 24)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - RAM Dropdown
    private var ramDropdownMenu: some View {
        let isFiltered = viewModel.compatibilityRamFilter != nil
        let displayText: String = {
            if let ram = viewModel.compatibilityRamFilter {
                return "\(ram)GB"
            } else {
                return viewModel.tr("compatibility.ram_filter").replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
            }
        }()
        
        return Menu {
            Button {
                SoundEffectService.shared.play(.click)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                    viewModel.compatibilityFocusArea = .filters
                    viewModel.compatibilityRamFilter = nil
                }
            } label: {
                HStack {
                    Text("\(viewModel.tr("compatibility.all")) (\(viewModel.compatibleGames.count))")
                    if viewModel.compatibilityRamFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            ForEach([4, 6, 8, 16], id: \.self) { ram in
                let count = viewModel.compatibleGames.filter { $0.minRamGB <= ram }.count
                Button {
                    SoundEffectService.shared.play(.click)
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                        viewModel.compatibilityFocusArea = .filters
                        viewModel.compatibilityRamFilter = ram
                    }
                } label: {
                    HStack {
                        Text("\(ram)GB RAM (\(count))")
                        if viewModel.compatibilityRamFilter == ram {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ramMenuLabel(isFiltered: isFiltered, displayText: displayText)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .nxNoFocusRing()
        .help(viewModel.compatibilityRamFilter == nil ? "Filter games by minimum RAM" : "Filtered: up to \(viewModel.compatibilityRamFilter!)GB RAM")
    }
    
    private func ramMenuLabel(isFiltered: Bool, displayText: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "memorychip")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isFiltered ? NXTheme.primary : NXTheme.secondary)
            
            Text(displayText)
                .font(.system(size: 11, weight: isFiltered ? .bold : .semibold, design: .rounded))
                .foregroundColor(isFiltered ? NXTheme.primary : .white)
            
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(isFiltered ? NXTheme.primary.opacity(0.85) : .white.opacity(0.65))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .nxGlassBar(
            in: Capsule(),
            fallbackFill: isFiltered ? NXTheme.primary.opacity(0.24) : NXTheme.glassSurfaceElevated.opacity(0.65),
            fallbackStroke: isFiltered ? NXTheme.primary.opacity(0.50) : NXTheme.borderSubtle
        )
        .nxGlassInteractive(
            in: Capsule(),
            tint: isFiltered ? NXTheme.primary.opacity(0.35) : nil
        )
    }
    
    // MARK: - iPhone / iPad Chip Dropdown
    private var chipDropdownMenu: some View {
        let isFiltered = viewModel.compatibilityChipFilter != nil
        let displayText: String = {
            if let chip = viewModel.compatibilityChipFilter {
                return chip.rawValue
            } else {
                return viewModel.tr("compatibility.iphone_chip_filter").replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
            }
        }()
        
        let aChips = IphoneChipTier.allCases.filter { !$0.isMSeries }
        let mChips = IphoneChipTier.allCases.filter { $0.isMSeries }
        
        return Menu {
            Button {
                SoundEffectService.shared.play(.click)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                    viewModel.compatibilityFocusArea = .filters
                    viewModel.compatibilityChipFilter = nil
                }
            } label: {
                HStack {
                    Text("\(viewModel.tr("compatibility.all")) (\(viewModel.compatibleGames.count))")
                    if viewModel.compatibilityChipFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            Section("A-Series (iPhone & iPad)") {
                ForEach(aChips) { tier in
                    let count = viewModel.compatibleGames.filter { $0.minChipTier <= tier }.count
                    Button {
                        SoundEffectService.shared.play(.click)
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                            viewModel.compatibilityFocusArea = .filters
                            viewModel.compatibilityChipFilter = tier
                        }
                    } label: {
                        HStack {
                            Text("\(tier.rawValue) — \(tier.deviceSummary) (\(count))")
                            if viewModel.compatibilityChipFilter == tier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Section("M-Series (iPad Pro / iPad Air / Mac)") {
                ForEach(mChips) { tier in
                    let count = viewModel.compatibleGames.filter { $0.minChipTier <= tier }.count
                    Button {
                        SoundEffectService.shared.play(.click)
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                            viewModel.compatibilityFocusArea = .filters
                            viewModel.compatibilityChipFilter = tier
                        }
                    } label: {
                        HStack {
                            Text("\(tier.rawValue) — \(tier.deviceSummary) (\(count))")
                            if viewModel.compatibilityChipFilter == tier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            chipMenuLabel(isFiltered: isFiltered, displayText: displayText)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .nxNoFocusRing()
        .help(viewModel.compatibilityChipFilter?.deviceSummary ?? "Filter games by Apple Silicon chip (iPhone / iPad)")
    }
    
    private func chipMenuLabel(isFiltered: Bool, displayText: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "ipad.and.iphone")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isFiltered ? NXTheme.primary : NXTheme.secondary)
            
            Text(displayText)
                .font(.system(size: 11, weight: isFiltered ? .bold : .semibold, design: .rounded))
                .foregroundColor(isFiltered ? NXTheme.primary : .white)
            
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(isFiltered ? NXTheme.primary.opacity(0.85) : .white.opacity(0.65))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .nxGlassBar(
            in: Capsule(),
            fallbackFill: isFiltered ? NXTheme.primary.opacity(0.24) : NXTheme.glassSurfaceElevated.opacity(0.65),
            fallbackStroke: isFiltered ? NXTheme.primary.opacity(0.50) : NXTheme.borderSubtle
        )
        .nxGlassInteractive(
            in: Capsule(),
            tint: isFiltered ? NXTheme.primary.opacity(0.35) : nil
        )
    }
    
    // MARK: - My Device Filter Button
    private var myDeviceButton: some View {
        let isFiltered = viewModel.compatibilityOnlyMyDevice
        
        return Button(action: {
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                viewModel.compatibilityFocusArea = .filters
                viewModel.compatibilityOnlyMyDevice.toggle()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isFiltered ? NXTheme.primary : NXTheme.secondary)
                
                Text(isFiltered ? "✓ \(viewModel.tr("compatibility.my_device")): \(viewModel.macPhysicalMemoryGB)GB" : "\(viewModel.tr("compatibility.my_device")): \(viewModel.macPhysicalMemoryGB)GB")
                    .font(.system(size: 11, weight: isFiltered ? .bold : .semibold, design: .rounded))
                    .foregroundColor(isFiltered ? NXTheme.primary : .white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .nxGlassBar(
                in: Capsule(),
                fallbackFill: isFiltered ? NXTheme.primary.opacity(0.24) : NXTheme.glassSurfaceElevated.opacity(0.65),
                fallbackStroke: isFiltered ? NXTheme.primary.opacity(0.50) : NXTheme.borderSubtle
            )
            .nxGlassInteractive(
                in: Capsule(),
                tint: isFiltered ? NXTheme.primary.opacity(0.35) : nil
            )
        }
        .buttonStyle(NXPressableButtonStyle())
        .nxNoFocusRing()
        .help("Show only games compatible with this Mac (\(viewModel.macPhysicalMemoryGB)GB RAM)")
    }

    // MARK: - Reset Button
    private var resetButton: some View {
        let intensity = viewModel.liquidGlassIntensity
        return Button(action: {
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                viewModel.compatibilityRamFilter = nil
                viewModel.compatibilityChipFilter = nil
                viewModel.compatibilityGenerationFilter = .all
                viewModel.compatibilityOnlyMyDevice = false
                viewModel.compatibilityNameFilter = "All"
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                Text(viewModel.tr("common.reset"))
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(NXTheme.tertiary.opacity(0.25 + 0.15 * intensity))
            )
            .overlay(
                Capsule()
                    .strokeBorder(NXTheme.tertiary.opacity(0.40 + 0.20 * intensity), lineWidth: 0.75)
            )
            .contentShape(Capsule())
            .nxGlassInteractive(
                in: Capsule(),
                tint: NXTheme.tertiary.opacity(0.40),
                fallbackFill: Color.clear
            )
            .nxGlassTransition(.materialize)
        }
        .buttonStyle(NXPressableButtonStyle())
        .nxNoFocusRing()
    }

    // MARK: - All Generation Dropdown Menu
    private var allGenerationDropdownMenu: some View {
        let isSelected = viewModel.compatibilityNameFilter == "All"
        let gen = viewModel.compatibilityGenerationFilter
        let displayText: String = {
            switch gen {
            case .all: return viewModel.tr("compatibility.all")
            case .switch1: return "Switch 1"
            case .switch2: return "Switch 2"
            }
        }()
        let intensity = viewModel.liquidGlassIntensity

        return Menu {
            Button(action: {
                SoundEffectService.shared.play(.click)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                    viewModel.compatibilityFocusArea = .filters
                    viewModel.compatibilityNameFilter = "All"
                    viewModel.compatibilityGenerationFilter = .all
                }
            }) {
                HStack {
                    Text(viewModel.tr("compatibility.switch_all"))
                    if gen == .all { Image(systemName: "checkmark") }
                }
            }
            Button(action: {
                SoundEffectService.shared.play(.click)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                    viewModel.compatibilityFocusArea = .filters
                    viewModel.compatibilityNameFilter = "All"
                    viewModel.compatibilityGenerationFilter = .switch1
                }
            }) {
                HStack {
                    Text(viewModel.tr("compatibility.switch1"))
                    if gen == .switch1 { Image(systemName: "checkmark") }
                }
            }
            Button(action: {
                SoundEffectService.shared.play(.click)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                    viewModel.compatibilityFocusArea = .filters
                    viewModel.compatibilityNameFilter = "All"
                    viewModel.compatibilityGenerationFilter = .switch2
                }
            }) {
                HStack {
                    Text(viewModel.tr("compatibility.switch2"))
                    if gen == .switch2 { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(displayText)
                    .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 7)
            .frame(minWidth: 42)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.clear : Color.white.opacity(0.04 + 0.04 * (1.0 - intensity)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.06 + 0.06 * intensity), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(NXPressableButtonStyle())
        .menuIndicator(.hidden)
        .fixedSize()
        .nxNoFocusRing()
        .matchedGeometryEffect(id: "All", in: alphaFilterNamespace, isSource: true)
    }
    
    // MARK: - Alphabet Buttons
    private func nameLetterButton(
        _ label: String,
        icon: String? = nil,
        filterKey: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let intensity = viewModel.liquidGlassIntensity
        return Button(action: {
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                viewModel.compatibilityFocusArea = .filters
                if isSelected && filterKey != "All" {
                    viewModel.compatibilityNameFilter = "All"
                } else {
                    action()
                }
            }
        }) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, label.count > 1 ? 7 : 0)
            .frame(minWidth: label.count > 1 ? 34 : 20)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.clear : Color.white.opacity(0.04 + 0.04 * (1.0 - intensity)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.06 + 0.06 * intensity), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(NXPressableButtonStyle())
        .nxNoFocusRing()
        .matchedGeometryEffect(id: filterKey, in: alphaFilterNamespace, isSource: true)
    }
}
