#!/bin/bash

# Function to get all user profiles
get_user_profiles() {
    local profiles=()
    # Get local user profiles
    for user_dir in /Users/*; do
        if [[ -d "$user_dir" && "$(basename "$user_dir")" != "Shared" && "$(basename "$user_dir")" != "Guest" ]]; then
            profiles+=("$user_dir")
        fi
    done
    # Add system profiles
    profiles+=("/Library")
    echo "${profiles[@]}"
}

# Function to get VSCode extensions
get_vscode_extensions() {
    echo -e "\nScanning for Visual Studio Code installations..."
    local extensions=()
    local found=false
    
    # Check for VSCode in common locations on macOS
    local vscode_paths=(
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    )
    
    for path in "${vscode_paths[@]}"; do
        if [ -f "$path" ]; then
            found=true
            echo "Found VSCode at: $path"
            
            # Get extensions
            if [ -f "$path" ]; then
                while IFS= read -r ext_name; do
                    local ext_path="$HOME/.vscode/extensions"
                    local ext_folder=$(find "$ext_path" -maxdepth 1 -type d -name "${ext_name}*" | head -n 1)
                    local ext_full_path=${ext_folder:-"Not found"}
                    
                    extensions+=("{\"IDE\":\"Visual Studio Code\",\"Extension\":\"$ext_name\",\"Path\":\"$ext_full_path\"}")
                done < <("$path" --list-extensions)
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo "Visual Studio Code not found in standard locations"
    fi
    
    echo "${extensions[@]}"
}

# Function to get JetBrains IDE extensions and plugins
get_jetbrains_extensions() {
    echo -e "\nScanning for JetBrains IDE installations..."
    local extensions=()
    local found=false
    
    # Add paths from all user profiles
    local jetbrains_paths=()
    for profile in $(get_user_profiles); do
        jetbrains_paths+=("$profile/Library/Application Support/JetBrains")
        jetbrains_paths+=("$profile/Library/Caches/JetBrains")
    done
    
    for path in "${jetbrains_paths[@]}"; do
        if [ -d "$path" ]; then
            found=true
            echo "Found JetBrains directory at: $path"
            
            # Get all JetBrains IDE folders
            while IFS= read -r ide_folder; do
                local ide_name=$(basename "$ide_folder")
                echo "Found JetBrains IDE: $ide_name"
                
                # Check for plugins in config directory
                local extensions_path="$ide_folder/plugins"
                if [ -d "$extensions_path" ]; then
                    echo "Scanning plugins in: $extensions_path"
                    while IFS= read -r ext_folder; do
                        local ext_name=$(basename "$ext_folder")
                        local plugin_xml_path="$ext_folder/META-INF/plugin.xml"
                        
                        # Try to get plugin name from XML
                        if [ -f "$plugin_xml_path" ]; then
                            local xml_name=$(grep -o '<name>.*</name>' "$plugin_xml_path" | sed 's/<name>\(.*\)<\/name>/\1/' | head -n 1)
                            if [ -n "$xml_name" ]; then
                                ext_name="$xml_name"
                            fi
                        fi
                        
                        extensions+=("{\"IDE\":\"$ide_name\",\"Type\":\"Plugin\",\"Extension\":\"$ext_name\",\"Path\":\"$ext_folder\"}")
                    done < <(find "$extensions_path" -maxdepth 1 -type d)
                fi
            done < <(find "$path" -maxdepth 1 -type d -name "IntelliJIdea*" -o -name "WebStorm*" -o -name "PyCharm*" -o -name "PhpStorm*" -o -name "Rider*" -o -name "CLion*" -o -name "GoLand*" -o -name "RubyMine*" -o -name "DataGrip*" -o -name "AppCode*")
        fi
    done
    
    # Also check for JetBrains IDEs in Applications
    local app_paths=(
        "/Applications"
        "$HOME/Applications"
    )
    
    for app_path in "${app_paths[@]}"; do
        if [ -d "$app_path" ]; then
            while IFS= read -r app; do
                local app_name=$(basename "$app" .app)
                if [[ "$app_name" =~ ^(IntelliJIdea|WebStorm|PyCharm|PhpStorm|Rider|CLion|GoLand|RubyMine|DataGrip|AppCode) ]]; then
                    found=true
                    echo "Found JetBrains IDE: $app_name"
                    
                    # Check for plugins in the app bundle
                    local plugins_path="$app/Contents/plugins"
                    if [ -d "$plugins_path" ]; then
                        echo "Scanning plugins in: $plugins_path"
                        while IFS= read -r ext_folder; do
                            local ext_name=$(basename "$ext_folder")
                            local plugin_xml_path="$ext_folder/META-INF/plugin.xml"
                            
                            # Try to get plugin name from XML
                            if [ -f "$plugin_xml_path" ]; then
                                local xml_name=$(grep -o '<name>.*</name>' "$plugin_xml_path" | sed 's/<name>\(.*\)<\/name>/\1/' | head -n 1)
                                if [ -n "$xml_name" ]; then
                                    ext_name="$xml_name"
                                fi
                            fi
                            
                            extensions+=("{\"IDE\":\"$app_name\",\"Type\":\"Plugin\",\"Extension\":\"$ext_name\",\"Path\":\"$ext_folder\"}")
                        done < <(find "$plugins_path" -maxdepth 1 -type d)
                    fi
                fi
            done < <(find "$app_path" -maxdepth 1 -type d -name "*.app")
        fi
    done
    
    if [ "$found" = false ]; then
        echo "JetBrains IDEs not found in standard locations"
    fi
    
    echo "${extensions[@]}"
}

# Function to get Cursor extensions
get_cursor_extensions() {
    echo -e "\nScanning for Cursor installations..."
    local extensions=()
    local found=false
    
    # Check for Cursor in common locations on macOS
    local cursor_paths=(
        "/Applications/Cursor.app/Contents/MacOS/Cursor"
        "$HOME/Applications/Cursor.app/Contents/MacOS/Cursor"
    )
    
    for path in "${cursor_paths[@]}"; do
        if [ -f "$path" ]; then
            found=true
            echo "Found Cursor at: $path"
            local extensions_path="$HOME/.cursor/extensions"
            
            if [ -d "$extensions_path" ]; then
                while IFS= read -r ext_folder; do
                    local ext_name=$(basename "$ext_folder")
                    local package_json_path="$ext_folder/package.json"
                    
                    # Try to get extension name from package.json
                    if [ -f "$package_json_path" ]; then
                        local json_name=$(grep -o '"name": "[^"]*"' "$package_json_path" | sed 's/"name": "\([^"]*\)"/\1/' | head -n 1)
                        if [ -n "$json_name" ]; then
                            ext_name="$json_name"
                        fi
                    fi
                    
                    extensions+=("{\"IDE\":\"Cursor\",\"Extension\":\"$ext_name\",\"Path\":\"$ext_folder\"}")
                done < <(find "$extensions_path" -maxdepth 1 -type d)
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo "Cursor not found in standard locations"
    fi
    
    echo "${extensions[@]}"
}

# Function to get Sublime Text packages
get_sublime_text_packages() {
    echo -e "\nScanning for Sublime Text installations..."
    local extensions=()
    local found=false
    
    # Check for Sublime Text in common locations on macOS
    local sublime_paths=(
        "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl"
        "/Applications/Sublime Text 3.app/Contents/SharedSupport/bin/subl"
        "/Applications/Sublime Text 4.app/Contents/SharedSupport/bin/subl"
        "$HOME/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl"
        "$HOME/Applications/Sublime Text 3.app/Contents/SharedSupport/bin/subl"
        "$HOME/Applications/Sublime Text 4.app/Contents/SharedSupport/bin/subl"
    )
    
    for path in "${sublime_paths[@]}"; do
        if [ -f "$path" ]; then
            found=true
            echo "Found Sublime Text at: $path"
        fi
    done
    
    # Common package locations on macOS
    local package_locations=(
        "$HOME/Library/Application Support/Sublime Text/Packages"
        "$HOME/Library/Application Support/Sublime Text 3/Packages"
        "$HOME/Library/Application Support/Sublime Text 4/Packages"
        "$HOME/Library/Application Support/Sublime Text/Installed Packages"
        "$HOME/Library/Application Support/Sublime Text 3/Installed Packages"
        "$HOME/Library/Application Support/Sublime Text 4/Installed Packages"
    )
    
    # Print all package locations being checked
    echo -e "\nChecking the following package locations:"
    for path in "${package_locations[@]}"; do
        echo "  - $path"
        if [ -d "$path" ]; then
            echo "    [FOUND]"
            found=true
        fi
    done
    
    if [ "$found" = true ]; then
        echo -e "\nFound Sublime Text installation or packages. Scanning for extensions..."
        
        # Check all possible package locations
        for package_path in "${package_locations[@]}"; do
            if [ -d "$package_path" ]; then
                echo "Scanning packages in: $package_path"
                
                # Handle both .sublime-package files and directories
                while IFS= read -r package_file; do
                    local package_name=$(basename "$package_file" .sublime-package)
                    extensions+=("{\"IDE\":\"Sublime Text\",\"Type\":\"Package\",\"Extension\":\"$package_name\",\"Path\":\"$package_file\"}")
                done < <(find "$package_path" -maxdepth 1 -type f -name "*.sublime-package")
                
                while IFS= read -r ext_folder; do
                    local ext_name=$(basename "$ext_folder")
                    local package_json_path="$ext_folder/package.json"
                    
                    # Try to get package name from package.json if it exists
                    if [ -f "$package_json_path" ]; then
                        local json_name=$(grep -o '"name": "[^"]*"' "$package_json_path" | sed 's/"name": "\([^"]*\)"/\1/' | head -n 1)
                        if [ -n "$json_name" ]; then
                            ext_name="$json_name"
                        fi
                    fi
                    
                    extensions+=("{\"IDE\":\"Sublime Text\",\"Type\":\"Package\",\"Extension\":\"$ext_name\",\"Path\":\"$ext_folder\"}")
                done < <(find "$package_path" -maxdepth 1 -type d)
            fi
        done
        
        # Also check for user packages in the User directory
        local user_packages_paths=(
            "$HOME/Library/Application Support/Sublime Text/Packages/User"
            "$HOME/Library/Application Support/Sublime Text 3/Packages/User"
            "$HOME/Library/Application Support/Sublime Text 4/Packages/User"
        )
        
        for user_packages_path in "${user_packages_paths[@]}"; do
            if [ -d "$user_packages_path" ]; then
                echo "Scanning user packages in: $user_packages_path"
                while IFS= read -r settings_file; do
                    local settings_name=$(basename "$settings_file" .sublime-settings)
                    extensions+=("{\"IDE\":\"Sublime Text\",\"Type\":\"User Settings\",\"Extension\":\"$settings_name\",\"Path\":\"$settings_file\"}")
                done < <(find "$user_packages_path" -maxdepth 1 -type f -name "*.sublime-settings")
            fi
        done
    else
        echo -e "\nSublime Text not found in standard locations. Please check if it's installed in a custom location."
    fi
    
    echo "${extensions[@]}"
}

# Function to get Atom packages
get_atom_packages() {
    echo -e "\nScanning for Atom installations..."
    local extensions=()
    local found=false
    
    # Check for Atom in common locations on macOS
    local atom_paths=(
        "/Applications/Atom.app/Contents/MacOS/Atom"
        "$HOME/Applications/Atom.app/Contents/MacOS/Atom"
    )
    
    for path in "${atom_paths[@]}"; do
        if [ -f "$path" ]; then
            found=true
            echo "Found Atom at: $path"
            local packages_path="$HOME/.atom/packages"
            
            if [ -d "$packages_path" ]; then
                while IFS= read -r ext_folder; do
                    local ext_name=$(basename "$ext_folder")
                    local package_json_path="$ext_folder/package.json"
                    
                    # Try to get package name from package.json
                    if [ -f "$package_json_path" ]; then
                        local json_name=$(grep -o '"name": "[^"]*"' "$package_json_path" | sed 's/"name": "\([^"]*\)"/\1/' | head -n 1)
                        if [ -n "$json_name" ]; then
                            ext_name="$json_name"
                        fi
                    fi
                    
                    extensions+=("{\"IDE\":\"Atom\",\"Extension\":\"$ext_name\",\"Path\":\"$ext_folder\"}")
                done < <(find "$packages_path" -maxdepth 1 -type d)
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo "Atom not found in standard locations"
    fi
    
    echo "${extensions[@]}"
}

# Function to get Eclipse plugins
get_eclipse_plugins() {
    echo -e "\nScanning for Eclipse installations..."
    local extensions=()
    local found=false
    
    # Check for Eclipse in common locations on macOS
    local eclipse_paths=(
        "/Applications/Eclipse.app"
        "$HOME/Applications/Eclipse.app"
        "/Applications/Eclipse.app/Contents/Eclipse"
        "$HOME/Applications/Eclipse.app/Contents/Eclipse"
    )
    
    for path in "${eclipse_paths[@]}"; do
        if [ -d "$path" ]; then
            found=true
            echo "Found Eclipse at: $path"
            
            # Get all Eclipse installations
            local plugins_path="$path/plugins"
            if [ -d "$plugins_path" ]; then
                echo "Found Eclipse plugins in: $plugins_path"
                while IFS= read -r plugin_file; do
                    local plugin_name=$(basename "$plugin_file")
                    extensions+=("{\"IDE\":\"Eclipse\",\"Extension\":\"$plugin_name\",\"Path\":\"$plugin_file\"}")
                done < <(find "$plugins_path" -maxdepth 1 -type f -name "*.jar")
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo "Eclipse not found in standard locations"
    fi
    
    echo "${extensions[@]}"
}

# Function to get Obsidian plugins
get_obsidian_plugins() {
    echo -e "\nScanning for Obsidian installations..."
    local extensions=()
    local found=false
    
    # Check for Obsidian in common locations on macOS
    local obsidian_paths=(
        "/Applications/Obsidian.app/Contents/MacOS/Obsidian"
        "$HOME/Applications/Obsidian.app/Contents/MacOS/Obsidian"
    )
    
    for path in "${obsidian_paths[@]}"; do
        if [ -f "$path" ]; then
            found=true
            echo "Found Obsidian at: $path"
        fi
    done
    
    # Common plugin locations on macOS
    local plugin_locations=(
        "$HOME/Library/Application Support/obsidian/plugins"
        "$HOME/Library/Application Support/obsidian/community-plugins.json"
    )
    
    # Print all plugin locations being checked
    echo -e "\nChecking the following plugin locations:"
    for path in "${plugin_locations[@]}"; do
        echo "  - $path"
        if [ -e "$path" ]; then
            echo "    [FOUND]"
            found=true
        fi
    done
    
    if [ "$found" = true ]; then
        echo -e "\nFound Obsidian installation or plugins. Scanning for extensions..."
        
        # Scan for installed plugins
        for plugin_path in "${plugin_locations[@]}"; do
            if [ -e "$plugin_path" ]; then
                if [[ "$plugin_path" == *.json ]]; then
                    # Handle community plugins list
                    echo "Scanning community plugins in: $plugin_path"
                    while IFS= read -r plugin_name; do
                        extensions+=("{\"IDE\":\"Obsidian\",\"Type\":\"Community Plugin\",\"Extension\":\"$plugin_name\",\"Path\":\"$plugin_path\"}")
                    done < <(grep -o '"name": "[^"]*"' "$plugin_path" | sed 's/"name": "\([^"]*\)"/\1/')
                elif [ -d "$plugin_path" ]; then
                    # Handle installed plugins directory
                    echo "Scanning installed plugins in: $plugin_path"
                    while IFS= read -r plugin_folder; do
                        local ext_name=$(basename "$plugin_folder")
                        local manifest_path="$plugin_folder/manifest.json"
                        
                        # Try to get plugin name from manifest.json
                        if [ -f "$manifest_path" ]; then
                            local json_name=$(grep -o '"name": "[^"]*"' "$manifest_path" | sed 's/"name": "\([^"]*\)"/\1/' | head -n 1)
                            if [ -n "$json_name" ]; then
                                ext_name="$json_name"
                            fi
                        fi
                        
                        extensions+=("{\"IDE\":\"Obsidian\",\"Type\":\"Plugin\",\"Extension\":\"$ext_name\",\"Path\":\"$plugin_folder\"}")
                    done < <(find "$plugin_path" -maxdepth 1 -type d)
                fi
            fi
        done
    else
        echo -e "\nObsidian not found in standard locations. Please check if it's installed in a custom location."
    fi
    
    echo "${extensions[@]}"
}

# Function to get TextMate bundles (macOS equivalent to Notepad++ plugins)
get_textmate_bundles() {
    echo -e "\nScanning for TextMate installations..."
    local extensions=()
    local found=false
    
    # Check for TextMate in common locations on macOS
    local textmate_paths=(
        "/Applications/TextMate.app"
        "$HOME/Applications/TextMate.app"
    )
    
    for path in "${textmate_paths[@]}"; do
        if [ -d "$path" ]; then
            found=true
            echo "Found TextMate at: $path"
        fi
    done
    
    # Common bundle locations on macOS
    local bundle_locations=(
        "$HOME/Library/Application Support/TextMate/Bundles"
        "$HOME/Library/Application Support/TextMate/Pristine Copy/Bundles"
    )
    
    # Print all bundle locations being checked
    echo -e "\nChecking the following bundle locations:"
    for path in "${bundle_locations[@]}"; do
        echo "  - $path"
        if [ -d "$path" ]; then
            echo "    [FOUND]"
            found=true
        fi
    done
    
    if [ "$found" = true ]; then
        echo -e "\nFound TextMate installation. Scanning for bundles..."
        
        # Check all possible bundle locations
        for bundle_path in "${bundle_locations[@]}"; do
            if [ -d "$bundle_path" ]; then
                echo "Scanning bundles in: $bundle_path"
                
                # Get all bundle directories
                while IFS= read -r bundle_dir; do
                    local bundle_name=$(basename "$bundle_dir")
                    extensions+=("{\"IDE\":\"TextMate\",\"Type\":\"Bundle\",\"Extension\":\"$bundle_name\",\"Path\":\"$bundle_dir\"}")
                done < <(find "$bundle_path" -maxdepth 1 -type d)
            fi
        done
    else
        echo -e "\nTextMate not found in standard locations. Please check if it's installed in a custom location."
    fi
    
    echo "${extensions[@]}"
}

# Function to get Xcode extensions and plugins
get_xcode_extensions() {
    echo -e "\nScanning for Xcode installations..."
    local extensions=()
    local found=false
    
    # Check for Xcode in common locations on macOS
    local xcode_paths=(
        "/Applications/Xcode.app"
        "$HOME/Applications/Xcode.app"
    )
    
    for path in "${xcode_paths[@]}"; do
        if [ -d "$path" ]; then
            found=true
            echo "Found Xcode at: $path"
            
            # Check for plugins in the app bundle
            local plugins_path="$path/Contents/PlugIns"
            if [ -d "$plugins_path" ]; then
                echo "Scanning plugins in: $plugins_path"
                while IFS= read -r plugin_dir; do
                    local plugin_name=$(basename "$plugin_dir" .xcplugin)
                    extensions+=("{\"IDE\":\"Xcode\",\"Type\":\"Plugin\",\"Extension\":\"$plugin_name\",\"Path\":\"$plugin_dir\"}")
                done < <(find "$plugins_path" -maxdepth 1 -type d -name "*.xcplugin")
            fi
            
            # Check for source editor extensions
            local source_editor_path="$path/Contents/SharedFrameworks/SourceEditor.framework/Versions/A/Resources"
            if [ -d "$source_editor_path" ]; then
                echo "Scanning source editor extensions in: $source_editor_path"
                while IFS= read -r ext_file; do
                    local ext_name=$(basename "$ext_file")
                    extensions+=("{\"IDE\":\"Xcode\",\"Type\":\"Source Editor Extension\",\"Extension\":\"$ext_name\",\"Path\":\"$ext_file\"}")
                done < <(find "$source_editor_path" -maxdepth 1 -type f -name "*.xctxtmacro")
            fi
            
            # Check for user scripts
            local user_scripts_path="$HOME/Library/Developer/Xcode/UserData/IB Support/UserScripts"
            if [ -d "$user_scripts_path" ]; then
                echo "Scanning user scripts in: $user_scripts_path"
                while IFS= read -r script_file; do
                    local script_name=$(basename "$script_file")
                    extensions+=("{\"IDE\":\"Xcode\",\"Type\":\"User Script\",\"Extension\":\"$script_name\",\"Path\":\"$script_file\"}")
                done < <(find "$user_scripts_path" -maxdepth 1 -type f)
            fi
            
            # Check for custom templates
            local templates_path="$HOME/Library/Developer/Xcode/Templates"
            if [ -d "$templates_path" ]; then
                echo "Scanning custom templates in: $templates_path"
                while IFS= read -r template_dir; do
                    local template_name=$(basename "$template_dir")
                    extensions+=("{\"IDE\":\"Xcode\",\"Type\":\"Custom Template\",\"Extension\":\"$template_name\",\"Path\":\"$template_dir\"}")
                done < <(find "$templates_path" -maxdepth 1 -type d)
            fi
            
            # Check for custom snippets
            local snippets_path="$HOME/Library/Developer/Xcode/UserData/IB Support/CodeSnippets"
            if [ -d "$snippets_path" ]; then
                echo "Scanning custom snippets in: $snippets_path"
                while IFS= read -r snippet_file; do
                    local snippet_name=$(basename "$snippet_file" .codesnippet)
                    extensions+=("{\"IDE\":\"Xcode\",\"Type\":\"Code Snippet\",\"Extension\":\"$snippet_name\",\"Path\":\"$snippet_file\"}")
                done < <(find "$snippets_path" -maxdepth 1 -type f -name "*.codesnippet")
            fi
            
            # Check for custom schemes
            local schemes_path="$HOME/Library/Developer/Xcode/UserData/xcschemes"
            if [ -d "$schemes_path" ]; then
                echo "Scanning custom schemes in: $schemes_path"
                while IFS= read -r scheme_file; do
                    local scheme_name=$(basename "$scheme_file" .xcscheme)
                    extensions+=("{\"IDE\":\"Xcode\",\"Type\":\"Custom Scheme\",\"Extension\":\"$scheme_name\",\"Path\":\"$scheme_file\"}")
                done < <(find "$schemes_path" -maxdepth 1 -type f -name "*.xcscheme")
            fi
        fi
    done
    
    # Check for Xcode command line tools
    if command -v xcode-select &> /dev/null; then
        local xcode_path=$(xcode-select -p)
        if [ -d "$xcode_path" ]; then
            echo "Found Xcode command line tools at: $xcode_path"
            
            # Check for plugins in the command line tools
            local clt_plugins_path="$xcode_path/usr/lib/swift/plugins"
            if [ -d "$clt_plugins_path" ]; then
                echo "Scanning command line tools plugins in: $clt_plugins_path"
                while IFS= read -r plugin_file; do
                    local plugin_name=$(basename "$plugin_file")
                    extensions+=("{\"IDE\":\"Xcode Command Line Tools\",\"Type\":\"Plugin\",\"Extension\":\"$plugin_name\",\"Path\":\"$plugin_file\"}")
                done < <(find "$clt_plugins_path" -maxdepth 1 -type f -name "*.swiftmodule")
            fi
        fi
    fi
    
    if [ "$found" = false ]; then
        echo "Xcode not found in standard locations"
    fi
    
    echo "${extensions[@]}"
}

# Main script
echo "Starting IDE extension scan..."
all_extensions=()

# Create output directory if it doesn't exist
output_dir="IDE_Extensions"
mkdir -p "$output_dir"

# Collect extensions from all IDEs
echo -e "\n=== Scanning for IDE Extensions ==="

# VSCode extensions
vscode_extensions=($(get_vscode_extensions))
if [ ${#vscode_extensions[@]} -gt 0 ]; then
    echo "Found ${#vscode_extensions[@]} VSCode extensions"
    all_extensions+=("${vscode_extensions[@]}")
fi

# JetBrains extensions
jetbrains_extensions=($(get_jetbrains_extensions))
if [ ${#jetbrains_extensions[@]} -gt 0 ]; then
    echo "Found ${#jetbrains_extensions[@]} JetBrains extensions"
    all_extensions+=("${jetbrains_extensions[@]}")
fi

# Cursor extensions
cursor_extensions=($(get_cursor_extensions))
if [ ${#cursor_extensions[@]} -gt 0 ]; then
    echo "Found ${#cursor_extensions[@]} Cursor extensions"
    all_extensions+=("${cursor_extensions[@]}")
fi

# Sublime Text packages
sublime_extensions=($(get_sublime_text_packages))
if [ ${#sublime_extensions[@]} -gt 0 ]; then
    echo "Found ${#sublime_extensions[@]} Sublime Text packages"
    all_extensions+=("${sublime_extensions[@]}")
fi

# Atom packages
atom_extensions=($(get_atom_packages))
if [ ${#atom_extensions[@]} -gt 0 ]; then
    echo "Found ${#atom_extensions[@]} Atom packages"
    all_extensions+=("${atom_extensions[@]}")
fi

# Eclipse plugins
eclipse_extensions=($(get_eclipse_plugins))
if [ ${#eclipse_extensions[@]} -gt 0 ]; then
    echo "Found ${#eclipse_extensions[@]} Eclipse plugins"
    all_extensions+=("${eclipse_extensions[@]}")
fi

# Obsidian plugins
obsidian_extensions=($(get_obsidian_plugins))
if [ ${#obsidian_extensions[@]} -gt 0 ]; then
    echo "Found ${#obsidian_extensions[@]} Obsidian plugins"
    all_extensions+=("${obsidian_extensions[@]}")
fi

# TextMate bundles
textmate_extensions=($(get_textmate_bundles))
if [ ${#textmate_extensions[@]} -gt 0 ]; then
    echo "Found ${#textmate_extensions[@]} TextMate bundles"
    all_extensions+=("${textmate_extensions[@]}")
fi

# Xcode extensions
xcode_extensions=($(get_xcode_extensions))
if [ ${#xcode_extensions[@]} -gt 0 ]; then
    echo "Found ${#xcode_extensions[@]} Xcode extensions"
    all_extensions+=("${xcode_extensions[@]}")
fi

# Export to JSON
echo "[" > "$output_dir/extensions.json"
for i in "${!all_extensions[@]}"; do
    echo -n "${all_extensions[$i]}" >> "$output_dir/extensions.json"
    if [ $i -lt $((${#all_extensions[@]}-1)) ]; then
        echo "," >> "$output_dir/extensions.json"
    fi
done
echo "]" >> "$output_dir/extensions.json"

# Export to CSV
echo "IDE,Type,Extension,Path" > "$output_dir/extensions.csv"
for ext in "${all_extensions[@]}"; do
    # Extract values from JSON
    ide=$(echo "$ext" | grep -o '"IDE":"[^"]*"' | sed 's/"IDE":"\([^"]*\)"/\1/')
    type=$(echo "$ext" | grep -o '"Type":"[^"]*"' | sed 's/"Type":"\([^"]*\)"/\1/' || echo "")
    extension=$(echo "$ext" | grep -o '"Extension":"[^"]*"' | sed 's/"Extension":"\([^"]*\)"/\1/')
    path=$(echo "$ext" | grep -o '"Path":"[^"]*"' | sed 's/"Path":"\([^"]*\)"/\1/')
    
    # Escape commas in values
    ide=$(echo "$ide" | sed 's/,/\\,/g')
    type=$(echo "$type" | sed 's/,/\\,/g')
    extension=$(echo "$extension" | sed 's/,/\\,/g')
    path=$(echo "$path" | sed 's/,/\\,/g')
    
    echo "$ide,$type,$extension,$path" >> "$output_dir/extensions.csv"
done

echo -e "\n=== Scan Complete ==="
echo "Total extensions found: ${#all_extensions[@]}"
echo "Extensions have been exported to:"
echo "JSON: $output_dir/extensions.json"
echo "CSV: $output_dir/extensions.csv" 