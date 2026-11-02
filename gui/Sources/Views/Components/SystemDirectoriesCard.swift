import SwiftUI

public struct SystemDirectoriesCard: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(viewModel.tr("system.dirs_title"), systemImage: "folder.fill.badge.gearshape")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                        .help(viewModel.tr("system.dirs_help"))
                    
                    Spacer()
                    
                    Text(viewModel.tr("common.auto_saved"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(NXTheme.secondary)
                }
                
                // Game ROMs Directories (Multi-Folder with Recursive Subfolders)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewModel.tr("system.roms_folder"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(NXTheme.textPrimary)
                        
                        Spacer()
                        
                        Text("\(viewModel.gameFolders.count) \(viewModel.tr("system.folders_count"))")
                            .font(.system(size: 11))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                    
                    if viewModel.gameFolders.isEmpty {
                        HStack {
                            Text(viewModel.tr("system.no_folder_selected"))
                                .font(.system(size: 12))
                                .foregroundColor(NXTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(NXTheme.glassSurfaceElevated)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(NXTheme.specularRim, lineWidth: 0.8)
                        )
                    } else {
                        VStack(spacing: 6) {
                            ForEach(viewModel.gameFolders, id: \.self) { folder in
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(NXTheme.secondary)
                                    
                                    Text(folder.path)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(NXTheme.textPrimary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Spacer()
                                    
                                    Button {
                                        SoundEffectService.shared.play(.click)
                                        viewModel.removeGameFolder(folder)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(.red.opacity(0.85))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(viewModel.tr("common.remove"))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(NXTheme.glassSurfaceElevated)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(NXTheme.specularRim, lineWidth: 0.8)
                                )
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.selectAdditionalGameFolder()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                Text(viewModel.tr("system.add_folder"))
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        
                        if !viewModel.gameFolders.isEmpty {
                            Button(viewModel.tr("common.clear_all")) {
                                SoundEffectService.shared.play(.click)
                                viewModel.gameFolders.removeAll()
                                viewModel.selectedGameFolder = nil
                                viewModel.scanAllGameFolders()
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                        }
                    }
                }
                
                Divider().opacity(0.2)
                
                // Native Mac Games Directories (.app non-switch games)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(viewModel.tr("system.nonswitch_games_folder"), systemImage: "gamecontroller.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(NXTheme.textPrimary)
                        
                        Spacer()
                        
                        Text("\(viewModel.nonSwitchGameFolders.count) \(viewModel.tr("system.folders_count"))")
                            .font(.system(size: 11))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                    
                    if viewModel.nonSwitchGameFolders.isEmpty {
                        HStack {
                            Text(viewModel.tr("system.no_nonswitch_folder_selected"))
                                .font(.system(size: 12))
                                .foregroundColor(NXTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(NXTheme.glassSurfaceElevated)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(NXTheme.specularRim, lineWidth: 0.8)
                        )
                    } else {
                        VStack(spacing: 6) {
                            ForEach(viewModel.nonSwitchGameFolders, id: \.self) { folder in
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(red: 0.20, green: 0.82, blue: 0.60))
                                    
                                    Text(folder.path)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(NXTheme.textPrimary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Spacer()
                                    
                                    Button {
                                        SoundEffectService.shared.play(.click)
                                        viewModel.removeNonSwitchGameFolder(folder)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(.red.opacity(0.85))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(viewModel.tr("common.remove"))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(NXTheme.glassSurfaceElevated)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(NXTheme.specularRim, lineWidth: 0.8)
                                )
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.selectAdditionalNonSwitchGameFolder()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                Text(viewModel.tr("system.add_nonswitch_folder"))
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.selectSingleNonSwitchGameFile()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.app")
                                Text(viewModel.tr("system.add_nonswitch_single_app"))
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        
                        if !viewModel.nonSwitchGameFolders.isEmpty {
                            Button(viewModel.tr("common.clear_all")) {
                                SoundEffectService.shared.play(.click)
                                viewModel.clearAllNonSwitchGameFolders()
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                        }
                    }
                }
                
                Divider().opacity(0.2)
                
                // Ported Games Library Directory
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.tr("system.ported_library_folder"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(NXTheme.textPrimary)
                    
                    HStack(spacing: 8) {
                        HStack {
                            if let lib = viewModel.libraryFolder {
                                Text(lib.path)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(NXTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            } else {
                                Text(viewModel.tr("system.default_games_folder"))
                                    .font(.system(size: 12))
                                    .foregroundColor(NXTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(NXTheme.glassSurfaceElevated)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(NXTheme.specularRim, lineWidth: 0.8)
                        )
                        
                        Button(viewModel.tr("common.change")) {
                            viewModel.selectLibraryFolder()
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        
                        Button(viewModel.tr("system.reset_default")) {
                            let defaultDir = URL(fileURLWithPath: viewModel.defaultInstallPath).appendingPathComponent("Games")
                            viewModel.libraryFolder = defaultDir
                            viewModel.refreshLibrary()
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                    }
                }
                
                Divider().opacity(0.2)
                
                // Hidden Games from Library
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(viewModel.tr("system.hidden_games_title"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(NXTheme.textPrimary)
                        
                        Spacer()
                        
                        if viewModel.hasHiddenGames {
                            Text("\(viewModel.hiddenGamesCount)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(NXTheme.secondary.opacity(0.25))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 8) {
                        HStack {
                            Image(systemName: viewModel.hasHiddenGames ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 12))
                                .foregroundColor(viewModel.hasHiddenGames ? NXTheme.secondary : NXTheme.textMuted)
                            
                            Text(viewModel.hasHiddenGames 
                                 ? "\(viewModel.hiddenGamesCount) " + viewModel.tr("system.hidden_games_count_suffix")
                                 : viewModel.tr("system.hidden_games_none"))
                                .font(.system(size: 12))
                                .foregroundColor(viewModel.hasHiddenGames ? NXTheme.textPrimary : NXTheme.textSecondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(NXTheme.glassSurfaceElevated)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(NXTheme.specularRim, lineWidth: 0.8)
                        )
                        
                        if viewModel.hasHiddenGames {
                            Button(viewModel.tr("system.restore_all_hidden")) {
                                viewModel.restoreAllHiddenGames()
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                        }
                    }
                }
            }
        }
    }
}
