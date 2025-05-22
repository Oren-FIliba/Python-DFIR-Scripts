# Function to get all user profiles
function Get-UserProfiles {
    $profiles = @()
    # Get local user profiles
    $profiles += Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notlike "*Public*" } | Select-Object -ExpandProperty FullName
    # Add system profiles
    $profiles += "$env:ProgramData"
    return $profiles
}

# Function to get VSCode extensions
function Get-VSCodeExtensions {
    Write-Host "`nScanning for Visual Studio Code installations..."
    $vscodePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:APPDATA\Local\Programs\Microsoft VS Code\bin\code.cmd"
    )
    
    $extensions = @()
    $found = $false
    
    foreach ($path in $vscodePaths) {
        if (Test-Path $path) {
            $found = $true
            Write-Host "Found VSCode at: $path"
            $extensions += & $path --list-extensions | ForEach-Object {
                $extName = $_
                $extensionPath = "$env:USERPROFILE\.vscode\extensions"
                $extFolder = Get-ChildItem -Path $extensionPath -Directory | Where-Object { $_.Name -like "$extName*" } | Select-Object -First 1
                $extFullPath = if ($extFolder) { $extFolder.FullName } else { "Not found" }
                
                [PSCustomObject]@{
                    IDE = "Visual Studio Code"
                    Extension = $extName
                    Path = $extFullPath
                }
            }
        }
    }
    
    if (-not $found) {
        Write-Host "Visual Studio Code not found in standard locations"
    }
    
    return $extensions
}

# Function to get Visual Studio extensions
function Get-VisualStudioExtensions {
    Write-Host "`nScanning for Visual Studio installations..."
    $vsPaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
    )
    
    $extensions = @()
    $found = $false
    
    foreach ($path in $vsPaths) {
        if (Test-Path $path) {
            $found = $true
            Write-Host "Found VS Installer at: $path"
            $vsInstances = & $path -format json | ConvertFrom-Json
            
            foreach ($instance in $vsInstances) {
                Write-Host "Found Visual Studio instance: $($instance.displayName)"
                $extensionPath = "$($instance.installationPath)\Common7\IDE\Extensions"
                if (Test-Path $extensionPath) {
                    $extensions += Get-ChildItem -Path $extensionPath -Directory | 
                        ForEach-Object {
                            $extFolder = $_
                            $manifestPath = Join-Path $extFolder.FullName "extension.vsixmanifest"
                            $extName = if (Test-Path $manifestPath) {
                                [xml]$manifest = Get-Content $manifestPath
                                $manifest.PackageManifest.Metadata.DisplayName
                            } else {
                                $extFolder.Name
                            }
                            
                            [PSCustomObject]@{
                                IDE = "Visual Studio $($instance.displayName)"
                                Extension = $extName
                                Path = $extFolder.FullName
                            }
                        }
                }
            }
        }
    }
    
    if (-not $found) {
        Write-Host "Visual Studio Installer not found in standard locations"
    }
    
    return $extensions
}

# Function to get JetBrains IDE extensions and plugins
function Get-JetBrainsExtensions {
    Write-Host "`nScanning for JetBrains IDE installations..."
    $jetbrainsPaths = @()
    
    # Add paths from all user profiles
    foreach ($profile in Get-UserProfiles) {
        $jetbrainsPaths += "$profile\AppData\Local\JetBrains"
        $jetbrainsPaths += "$profile\AppData\Roaming\JetBrains"
    }
    
    $extensions = @()
    $found = $false
    
    foreach ($path in $jetbrainsPaths) {
        if (Test-Path $path) {
            $found = $true
            Write-Host "Found JetBrains directory at: $path"
            
            # Get all JetBrains IDE folders
            $ideFolders = Get-ChildItem -Path $path -Directory | Where-Object { 
                $_.Name -match "^(IntelliJIdea|WebStorm|PyCharm|PhpStorm|Rider|CLion|GoLand|RubyMine|DataGrip|AppCode)"
            }
            
            foreach ($ideFolder in $ideFolders) {
                Write-Host "Found JetBrains IDE: $($ideFolder.Name)"
                
                # Function to get plugin name from XML or directory
                function Get-PluginName {
                    param (
                        [string]$pluginXmlPath,
                        [string]$directoryName
                    )
                    
                    if (Test-Path $pluginXmlPath) {
                        try {
                            [xml]$pluginXml = Get-Content $pluginXmlPath
                            $ns = New-Object System.Xml.XmlNamespaceManager($pluginXml.NameTable)
                            $ns.AddNamespace("idea", "http://jetbrains.com/idea/plugin")
                            $nameNode = $pluginXml.SelectSingleNode("//idea:name", $ns)
                            if ($nameNode -and $nameNode.InnerText) {
                                return $nameNode.InnerText
                            }
                        } catch {
                            Write-Warning "Error parsing plugin.xml for ${directoryName}: $($_.Exception.Message)"
                        }
                    }
                    return $directoryName
                }
                
                # Check for plugins in config directory
                $extensionsPath = Join-Path $ideFolder.FullName "config\plugins"
                if (Test-Path $extensionsPath) {
                    Write-Host "Scanning plugins in: $extensionsPath"
                    $extensions += Get-ChildItem -Path $extensionsPath -Directory | 
                        ForEach-Object {
                            $extFolder = $_
                            $pluginXmlPath = Join-Path $extFolder.FullName "META-INF\plugin.xml"
                            $extName = Get-PluginName -pluginXmlPath $pluginXmlPath -directoryName $extFolder.Name
                            
                            [PSCustomObject]@{
                                IDE = $ideFolder.Name
                                Type = "Plugin"
                                Extension = $extName
                                Path = $extFolder.FullName
                            }
                        }
                }
                
                # Check for plugins in the IDE's plugins directory
                $idePluginsPath = Join-Path $ideFolder.FullName "plugins"
                if (Test-Path $idePluginsPath) {
                    Write-Host "Scanning IDE plugins in: $idePluginsPath"
                    $extensions += Get-ChildItem -Path $idePluginsPath -Directory | 
                        ForEach-Object {
                            $extFolder = $_
                            $pluginXmlPath = Join-Path $extFolder.FullName "META-INF\plugin.xml"
                            $extName = Get-PluginName -pluginXmlPath $pluginXmlPath -directoryName $extFolder.Name
                            
                            [PSCustomObject]@{
                                IDE = $ideFolder.Name
                                Type = "IDE Plugin"
                                Extension = $extName
                                Path = $extFolder.FullName
                            }
                        }
                }
                
                # Check for Python-specific plugins in PyCharm
                if ($ideFolder.Name -like "*PyCharm*") {
                    Write-Host "`nScanning PyCharm plugins..."
                    
                    # Check multiple possible plugin locations
                    $pythonPluginPaths = @(
                        (Join-Path $ideFolder.FullName "plugins\python"),
                        (Join-Path $ideFolder.FullName "plugins\python-core"),
                        (Join-Path $ideFolder.FullName "plugins\python-ce"),
                        (Join-Path $ideFolder.FullName "plugins\python-community")
                    )
                    
                    foreach ($pythonPluginsPath in $pythonPluginPaths) {
                        if (Test-Path $pythonPluginsPath) {
                            Write-Host "Scanning Python plugins in: $pythonPluginsPath"
                            $extensions += Get-ChildItem -Path $pythonPluginsPath -Directory | 
                                ForEach-Object {
                                    $extFolder = $_
                                    Write-Host "Processing plugin: $($extFolder.Name)"
                                    
                                    # Try multiple possible XML locations
                                    $pluginXmlPaths = @(
                                        (Join-Path $extFolder.FullName "META-INF\plugin.xml"),
                                        (Join-Path $extFolder.FullName "plugin.xml")
                                    )
                                    
                                    $extName = $extFolder.Name
                                    foreach ($pluginXmlPath in $pluginXmlPaths) {
                                        if (Test-Path $pluginXmlPath) {
                                            try {
                                                [xml]$pluginXml = Get-Content $pluginXmlPath
                                                $ns = New-Object System.Xml.XmlNamespaceManager($pluginXml.NameTable)
                                                $ns.AddNamespace("idea", "http://jetbrains.com/idea/plugin")
                                                
                                                # Try different possible name locations in the XML
                                                $nameNodes = @(
                                                    $pluginXml.SelectSingleNode("//idea:name", $ns),
                                                    $pluginXml.SelectSingleNode("//name", $ns),
                                                    $pluginXml.SelectSingleNode("//idea-plugin/name", $ns)
                                                )
                                                
                                                foreach ($nameNode in $nameNodes) {
                                                    if ($nameNode -and $nameNode.InnerText) {
                                                        $extName = $nameNode.InnerText
                                                        Write-Host "Found plugin name: $extName"
                                                        break
                                                    }
                                                }
                                            } catch {
                                                Write-Warning "Error parsing plugin.xml for ${extFolder.Name}: $($_.Exception.Message)"
                                            }
                                        }
                                    }
                                    
                                    [PSCustomObject]@{
                                        IDE = $ideFolder.Name
                                        Type = "Python Plugin"
                                        Extension = $extName
                                        Path = $extFolder.FullName
                                    }
                                }
                        }
                    }
                }
            }
        }
    }
    
    if (-not $found) {
        Write-Host "JetBrains IDEs not found in standard locations"
    }
    
    return $extensions
}

# Function to get Cursor extensions
function Get-CursorExtensions {
    Write-Host "`nScanning for Cursor installations..."
    $cursorPaths = @(
        "$env:LOCALAPPDATA\Programs\Cursor\Cursor.exe",
        "$env:APPDATA\Local\Programs\Cursor\Cursor.exe"
    )
    
    $extensions = @()
    $found = $false
    
    foreach ($path in $cursorPaths) {
        if (Test-Path $path) {
            $found = $true
            Write-Host "Found Cursor at: $path"
            $extensionsPath = "$env:USERPROFILE\.cursor\extensions"
            
            if (Test-Path $extensionsPath) {
                $extensions += Get-ChildItem -Path $extensionsPath -Directory | 
                    ForEach-Object {
                        $extFolder = $_
                        $packageJsonPath = Join-Path $extFolder.FullName "package.json"
                        $extName = if (Test-Path $packageJsonPath) {
                            $packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
                            $packageJson.name
                        } else {
                            $extFolder.Name
                        }
                        
                        [PSCustomObject]@{
                            IDE = "Cursor"
                            Extension = $extName
                            Path = $extFolder.FullName
                        }
                    }
            }
        }
    }
    
    if (-not $found) {
        Write-Host "Cursor not found in standard locations"
    }
    
    return $extensions
}

# Function to get Sublime Text packages
function Get-SublimeTextPackages {
    Write-Host "`nScanning for Sublime Text installations..."
    
    # Expanded paths to check for Sublime Text installation
    $sublimePaths = @(
        "$env:ProgramFiles\Sublime Text 3",
        "$env:ProgramFiles\Sublime Text 4",
        "$env:ProgramFiles (x86)\Sublime Text 3",
        "$env:ProgramFiles (x86)\Sublime Text 4",
        "$env:ProgramFiles\Sublime Text",
        "$env:ProgramFiles (x86)\Sublime Text",
        "$env:LOCALAPPDATA\Programs\Sublime Text 3",
        "$env:LOCALAPPDATA\Programs\Sublime Text 4",
        "$env:APPDATA\Local\Programs\Sublime Text 3",
        "$env:APPDATA\Local\Programs\Sublime Text 4",
        "$env:ProgramFiles\Sublime Text 3\sublime_text.exe",
        "$env:ProgramFiles\Sublime Text 4\sublime_text.exe",
        "$env:ProgramFiles (x86)\Sublime Text 3\sublime_text.exe",
        "$env:ProgramFiles (x86)\Sublime Text 4\sublime_text.exe"
    )
    
    $extensions = @()
    $found = $false
    
    # Print all paths being checked for debugging
    Write-Host "Checking the following installation paths:"
    foreach ($path in $sublimePaths) {
        Write-Host "  - $path"
        if (Test-Path $path) {
            Write-Host "    [FOUND]"
            $found = $true
        }
    }
    
    # Common package locations
    $packageLocations = @(
        "$env:APPDATA\Sublime Text\Packages",
        "$env:APPDATA\Sublime Text 3\Packages",
        "$env:APPDATA\Sublime Text 4\Packages",
        "$env:APPDATA\Sublime Text\Installed Packages",
        "$env:APPDATA\Sublime Text 3\Installed Packages",
        "$env:APPDATA\Sublime Text 4\Installed Packages",
        "$env:LOCALAPPDATA\Sublime Text\Packages",
        "$env:LOCALAPPDATA\Sublime Text 3\Packages",
        "$env:LOCALAPPDATA\Sublime Text 4\Packages",
        "$env:LOCALAPPDATA\Sublime Text\Installed Packages",
        "$env:LOCALAPPDATA\Sublime Text 3\Installed Packages",
        "$env:LOCALAPPDATA\Sublime Text 4\Installed Packages"
    )
    
    # Print all package locations being checked
    Write-Host "`nChecking the following package locations:"
    foreach ($path in $packageLocations) {
        Write-Host "  - $path"
        if (Test-Path $path) {
            Write-Host "    [FOUND]"
            $found = $true
        }
    }
    
    # Try to find Sublime Text executable in PATH
    $sublimeExe = Get-Command sublime_text -ErrorAction SilentlyContinue
    if ($sublimeExe) {
        Write-Host "`nFound Sublime Text in PATH: $($sublimeExe.Source)"
        $found = $true
    }
    
    # If we found any Sublime Text related paths, proceed with scanning
    if ($found) {
        Write-Host "`nFound Sublime Text installation or packages. Scanning for extensions..."
        
        # Check all possible package locations
        foreach ($packagePath in $packageLocations) {
            if (Test-Path $packagePath) {
                Write-Host "Scanning packages in: $packagePath"
                
                # Handle both .sublime-package files and directories
                $extensions += Get-ChildItem -Path $packagePath -File -Filter "*.sublime-package" | 
                    ForEach-Object {
                        $packageFile = $_
                        [PSCustomObject]@{
                            IDE = "Sublime Text"
                            Type = "Package"
                            Extension = $packageFile.BaseName
                            Path = $packageFile.FullName
                        }
                    }
                
                $extensions += Get-ChildItem -Path $packagePath -Directory | 
                    ForEach-Object {
                        $extFolder = $_
                        # Try to get package name from package.json if it exists
                        $packageJsonPath = Join-Path $extFolder.FullName "package.json"
                        $extName = if (Test-Path $packageJsonPath) {
                            try {
                                $packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
                                $packageJson.name
                            } catch {
                                $extFolder.Name
                            }
                        } else {
                            $extFolder.Name
                        }
                        
                        [PSCustomObject]@{
                            IDE = "Sublime Text"
                            Type = "Package"
                            Extension = $extName
                            Path = $extFolder.FullName
                        }
                    }
            }
        }
        
        # Also check for user packages in the User directory
        $userPackagesPaths = @(
            "$env:APPDATA\Sublime Text\Packages\User",
            "$env:APPDATA\Sublime Text 3\Packages\User",
            "$env:APPDATA\Sublime Text 4\Packages\User",
            "$env:LOCALAPPDATA\Sublime Text\Packages\User",
            "$env:LOCALAPPDATA\Sublime Text 3\Packages\User",
            "$env:LOCALAPPDATA\Sublime Text 4\Packages\User"
        )
        
        foreach ($userPackagesPath in $userPackagesPaths) {
            if (Test-Path $userPackagesPath) {
                Write-Host "Scanning user packages in: $userPackagesPath"
                $extensions += Get-ChildItem -Path $userPackagesPath -File -Filter "*.sublime-settings" | 
                    ForEach-Object {
                        $settingsFile = $_
                        [PSCustomObject]@{
                            IDE = "Sublime Text"
                            Type = "User Settings"
                            Extension = $settingsFile.BaseName
                            Path = $settingsFile.FullName
                        }
                    }
            }
        }
    } else {
        Write-Host "`nSublime Text not found in standard locations. Please check if it's installed in a custom location."
    }
    
    return $extensions
}

# Function to get Atom packages
function Get-AtomPackages {
    Write-Host "`nScanning for Atom installations..."
    $atomPaths = @(
        "$env:LOCALAPPDATA\atom\atom.exe",
        "$env:APPDATA\Local\atom\atom.exe"
    )
    
    $extensions = @()
    $found = $false
    
    foreach ($path in $atomPaths) {
        if (Test-Path $path) {
            $found = $true
            Write-Host "Found Atom at: $path"
            $packagesPath = "$env:USERPROFILE\.atom\packages"
            
            if (Test-Path $packagesPath) {
                $extensions += Get-ChildItem -Path $packagesPath -Directory | 
                    ForEach-Object {
                        $extFolder = $_
                        $packageJsonPath = Join-Path $extFolder.FullName "package.json"
                        $extName = if (Test-Path $packageJsonPath) {
                            $packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
                            $packageJson.name
                        } else {
                            $extFolder.Name
                        }
                        
                        [PSCustomObject]@{
                            IDE = "Atom"
                            Extension = $extName
                            Path = $extFolder.FullName
                        }
                    }
            }
        }
    }
    
    if (-not $found) {
        Write-Host "Atom not found in standard locations"
    }
    
    return $extensions
}

# Function to get Eclipse plugins
function Get-EclipsePlugins {
    Write-Host "`nScanning for Eclipse installations..."
    $eclipsePaths = @(
        "$env:ProgramFiles\Eclipse",
        "$env:ProgramFiles (x86)\Eclipse"
    )
    
    $extensions = @()
    $found = $false
    
    foreach ($path in $eclipsePaths) {
        if (Test-Path $path) {
            $found = $true
            Write-Host "Found Eclipse at: $path"
            
            # Get all Eclipse installations
            $eclipseInstalls = Get-ChildItem -Path $path -Directory | Where-Object { $_.Name -like "eclipse*" }
            
            foreach ($install in $eclipseInstalls) {
                Write-Host "Found Eclipse installation: $($install.Name)"
                $pluginsPath = Join-Path $install.FullName "plugins"
                
                if (Test-Path $pluginsPath) {
                    $extensions += Get-ChildItem -Path $pluginsPath -File -Filter "*.jar" | 
                        ForEach-Object {
                            $pluginFile = $_
                            [PSCustomObject]@{
                                IDE = "Eclipse $($install.Name)"
                                Extension = $pluginFile.Name
                                Path = $pluginFile.FullName
                            }
                        }
                }
            }
        }
    }
    
    if (-not $found) {
        Write-Host "Eclipse not found in standard locations"
    }
    
    return $extensions
}

# Function to get Obsidian plugins and community plugins
function Get-ObsidianPlugins {
    Write-Host "`nScanning for Obsidian installations..."
    $obsidianPaths = @(
        "$env:LOCALAPPDATA\Obsidian\Obsidian.exe",
        "$env:APPDATA\Local\Obsidian\Obsidian.exe",
        "$env:ProgramFiles\Obsidian\Obsidian.exe",
        "$env:ProgramFiles (x86)\Obsidian\Obsidian.exe"
    )
    
    $extensions = @()
    $found = $false
    
    # Print all paths being checked for debugging
    Write-Host "Checking the following installation paths:"
    foreach ($path in $obsidianPaths) {
        Write-Host "  - $path"
        if (Test-Path $path) {
            Write-Host "    [FOUND]"
            $found = $true
        }
    }
    
    # Common plugin locations
    $pluginLocations = @(
        "$env:APPDATA\obsidian\plugins",
        "$env:LOCALAPPDATA\obsidian\plugins",
        "$env:APPDATA\obsidian\community-plugins.json",
        "$env:LOCALAPPDATA\obsidian\community-plugins.json"
    )
    
    # Print all plugin locations being checked
    Write-Host "`nChecking the following plugin locations:"
    foreach ($path in $pluginLocations) {
        Write-Host "  - $path"
        if (Test-Path $path) {
            Write-Host "    [FOUND]"
            $found = $true
        }
    }
    
    if ($found) {
        Write-Host "`nFound Obsidian installation or plugins. Scanning for extensions..."
        
        # Scan for installed plugins
        foreach ($pluginPath in $pluginLocations) {
            if (Test-Path $pluginPath) {
                if ($pluginPath -like "*.json") {
                    # Handle community plugins list
                    Write-Host "Scanning community plugins in: $pluginPath"
                    try {
                        $plugins = Get-Content $pluginPath | ConvertFrom-Json
                        foreach ($plugin in $plugins) {
                            [PSCustomObject]@{
                                IDE = "Obsidian"
                                Type = "Community Plugin"
                                Extension = $plugin.name
                                Path = $pluginPath
                            }
                        }
                    } catch {
                        Write-Warning "Error parsing community plugins file: $($_.Exception.Message)"
                    }
                } else {
                    # Handle installed plugins directory
                    Write-Host "Scanning installed plugins in: $pluginPath"
                    $extensions += Get-ChildItem -Path $pluginPath -Directory | 
                        ForEach-Object {
                            $pluginFolder = $_
                            $manifestPath = Join-Path $pluginFolder.FullName "manifest.json"
                            $extName = if (Test-Path $manifestPath) {
                                try {
                                    $manifest = Get-Content $manifestPath | ConvertFrom-Json
                                    $manifest.name
                                } catch {
                                    $pluginFolder.Name
                                }
                            } else {
                                $pluginFolder.Name
                            }
                            
                            [PSCustomObject]@{
                                IDE = "Obsidian"
                                Type = "Plugin"
                                Extension = $extName
                                Path = $pluginFolder.FullName
                            }
                        }
                }
            }
        }
    } else {
        Write-Host "`nObsidian not found in standard locations. Please check if it's installed in a custom location."
    }
    
    return $extensions
}

# Function to get Notepad++ plugins
function Get-NotepadPlusPlusPlugins {
    Write-Host "`nScanning for Notepad++ installations..."
    $nppPaths = @(
        "$env:ProgramFiles\Notepad++",
        "$env:ProgramFiles (x86)\Notepad++",
        "$env:LOCALAPPDATA\Programs\Notepad++",
        "$env:APPDATA\Local\Programs\Notepad++",
        "$env:ProgramFiles\Notepad++\notepad++.exe",
        "$env:ProgramFiles (x86)\Notepad++\notepad++.exe",
        "$env:LOCALAPPDATA\Programs\Notepad++\notepad++.exe",
        "$env:APPDATA\Local\Programs\Notepad++\notepad++.exe",
        "C:\Program Files\Notepad++",
        "C:\Program Files (x86)\Notepad++",
        "C:\Program Files\Notepad++\notepad++.exe",
        "C:\Program Files (x86)\Notepad++\notepad++.exe"
    )
    
    $extensions = @()
    $found = $false
    $installationPath = $null
    
    # Print all paths being checked for debugging
    Write-Host "Checking the following installation paths:"
    foreach ($path in $nppPaths) {
        Write-Host "  - $path"
        if (Test-Path $path) {
            Write-Host "    [FOUND]"
            $found = $true
            if (-not $installationPath -and $path -like "*.exe") {
                $installationPath = Split-Path $path -Parent
            } elseif (-not $installationPath) {
                $installationPath = $path
            }
        }
    }
    
    # Try to find Notepad++ executable in PATH
    $nppExe = Get-Command notepad++ -ErrorAction SilentlyContinue
    if ($nppExe) {
        Write-Host "`nFound Notepad++ in PATH: $($nppExe.Source)"
        $found = $true
        if (-not $installationPath) {
            $installationPath = Split-Path $nppExe.Source -Parent
        }
    }
    
    # Try to find Notepad++ in registry
    try {
        $nppRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notepad++.exe"
        if (Test-Path $nppRegPath) {
            $nppPath = (Get-ItemProperty -Path $nppRegPath -Name "(Default)")."(Default)"
            if (Test-Path $nppPath) {
                Write-Host "`nFound Notepad++ in registry: $nppPath"
                $found = $true
                if (-not $installationPath) {
                    $installationPath = Split-Path $nppPath -Parent
                }
            }
        }
    } catch {
        Write-Warning "Error checking registry for Notepad++: $($_.Exception.Message)"
    }
    
    if ($found) {
        Write-Host "`nFound Notepad++ installation at: $installationPath"
        
        # Define all possible plugin locations
        $pluginLocations = @(
            (Join-Path $installationPath "plugins"),
            "$env:APPDATA\Notepad++\plugins",
            "$env:LOCALAPPDATA\Notepad++\plugins",
            "$env:ProgramFiles\Notepad++\plugins",
            "$env:ProgramFiles (x86)\Notepad++\plugins",
            "$env:LOCALAPPDATA\Programs\Notepad++\plugins",
            "$env:APPDATA\Local\Programs\Notepad++\plugins",
            "C:\Program Files\Notepad++\plugins",
            "C:\Program Files (x86)\Notepad++\plugins"
        )
        
        # Print all plugin locations being checked
        Write-Host "`nChecking the following plugin locations:"
        foreach ($path in $pluginLocations) {
            Write-Host "  - $path"
            if (Test-Path $path) {
                Write-Host "    [FOUND]"
                Write-Host "    Scanning for plugins..."
                
                # Get all plugin directories
                $pluginDirs = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue
                if ($pluginDirs) {
                    Write-Host "    Found $($pluginDirs.Count) plugin directories"
                    foreach ($pluginDir in $pluginDirs) {
                        Write-Host "      - $($pluginDir.Name)"
                        $extensions += [PSCustomObject]@{
                            IDE = "Notepad++"
                            Type = "Plugin"
                            Extension = $pluginDir.Name
                            Path = $pluginDir.FullName
                        }
                    }
                } else {
                    Write-Host "    No plugin directories found"
                }
            }
        }
        
        # Check for user-defined languages
        $userDefinePath = Join-Path $installationPath "userDefineLang"
        if (Test-Path $userDefinePath) {
            Write-Host "`nScanning user-defined languages in: $userDefinePath"
            $langFiles = Get-ChildItem -Path $userDefinePath -File -Filter "*.xml" -ErrorAction SilentlyContinue
            if ($langFiles) {
                Write-Host "Found $($langFiles.Count) user-defined language files"
                $extensions += $langFiles | ForEach-Object {
                    [PSCustomObject]@{
                        IDE = "Notepad++"
                        Type = "User Language"
                        Extension = $_.BaseName
                        Path = $_.FullName
                    }
                }
            }
        }
        
        # Check for user scripts
        $scriptsPath = Join-Path $installationPath "scripts"
        if (Test-Path $scriptsPath) {
            Write-Host "`nScanning user scripts in: $scriptsPath"
            $scriptFiles = Get-ChildItem -Path $scriptsPath -File -Filter "*.py" -ErrorAction SilentlyContinue
            if ($scriptFiles) {
                Write-Host "Found $($scriptFiles.Count) Python script files"
                $extensions += $scriptFiles | ForEach-Object {
                    [PSCustomObject]@{
                        IDE = "Notepad++"
                        Type = "Python Script"
                        Extension = $_.BaseName
                        Path = $_.FullName
                    }
                }
            }
        }
        
        # Check for additional plugin locations
        $additionalPluginPaths = @(
            (Join-Path $installationPath "plugins\config"),
            (Join-Path $installationPath "plugins\doc"),
            (Join-Path $installationPath "plugins\NppPlugin")
        )
        
        foreach ($pluginPath in $additionalPluginPaths) {
            if (Test-Path $pluginPath) {
                Write-Host "`nScanning additional plugins in: $pluginPath"
                $additionalPlugins = Get-ChildItem -Path $pluginPath -Directory -ErrorAction SilentlyContinue
                if ($additionalPlugins) {
                    Write-Host "Found $($additionalPlugins.Count) additional plugin directories"
                    $extensions += $additionalPlugins | ForEach-Object {
                        [PSCustomObject]@{
                            IDE = "Notepad++"
                            Type = "Plugin"
                            Extension = $_.Name
                            Path = $_.FullName
                        }
                    }
                }
            }
        }
    } else {
        Write-Host "`nNotepad++ not found in standard locations. Please check if it's installed in a custom location."
    }
    
    return $extensions
}

# Main script
Write-Host "Starting IDE extension scan..."
$allExtensions = @()

# Collect extensions from all IDEs
Write-Host "`n=== Scanning for IDE Extensions ==="
$vscodeExtensions = Get-VSCodeExtensions
if ($vscodeExtensions) {
    Write-Host "Found $($vscodeExtensions.Count) VSCode extensions"
    $allExtensions += $vscodeExtensions
}

$vsExtensions = Get-VisualStudioExtensions
if ($vsExtensions) {
    Write-Host "Found $($vsExtensions.Count) Visual Studio extensions"
    $allExtensions += $vsExtensions
}

$jetbrainsExtensions = Get-JetBrainsExtensions
if ($jetbrainsExtensions) {
    Write-Host "Found $($jetbrainsExtensions.Count) JetBrains extensions"
    $allExtensions += $jetbrainsExtensions
}

$cursorExtensions = Get-CursorExtensions
if ($cursorExtensions) {
    Write-Host "Found $($cursorExtensions.Count) Cursor extensions"
    $allExtensions += $cursorExtensions
}

$sublimeExtensions = Get-SublimeTextPackages
if ($sublimeExtensions) {
    Write-Host "Found $($sublimeExtensions.Count) Sublime Text packages"
    $allExtensions += $sublimeExtensions
}

$atomExtensions = Get-AtomPackages
if ($atomExtensions) {
    Write-Host "Found $($atomExtensions.Count) Atom packages"
    $allExtensions += $atomExtensions
}

$eclipseExtensions = Get-EclipsePlugins
if ($eclipseExtensions) {
    Write-Host "Found $($eclipseExtensions.Count) Eclipse plugins"
    $allExtensions += $eclipseExtensions
}

$obsidianExtensions = Get-ObsidianPlugins
if ($obsidianExtensions) {
    Write-Host "Found $($obsidianExtensions.Count) Obsidian plugins"
    $allExtensions += $obsidianExtensions
}

$nppExtensions = Get-NotepadPlusPlusPlugins
if ($nppExtensions) {
    Write-Host "Found $($nppExtensions.Count) Notepad++ plugins"
    $allExtensions += $nppExtensions
}

# Create output directory if it doesn't exist
$outputDir = "IDE_Extensions"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Export to JSON
$allExtensions | ConvertTo-Json | Out-File -FilePath "$outputDir\extensions.json" -Encoding UTF8

# Export to CSV
$allExtensions | Export-Csv -Path "$outputDir\extensions.csv" -NoTypeInformation -Encoding UTF8

Write-Host "`n=== Scan Complete ==="
Write-Host "Total extensions found: $($allExtensions.Count)"
Write-Host "Extensions have been exported to:"
Write-Host "JSON: $outputDir\extensions.json"
Write-Host "CSV: $outputDir\extensions.csv"

