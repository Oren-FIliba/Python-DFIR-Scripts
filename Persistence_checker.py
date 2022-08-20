import os
import subprocess
from shutil import make_archive



path = rf"C:\Windows\Tasks"
directory = "Artifacts"
location = os.path.join(path, directory)
os.makedirs(location)


def reg():
    print(location)
    reg_keys = [r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run", r"HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce", r"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", r"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Notify", r"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Shell", r"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", r"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects", r"HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run", r"HKLM\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components", r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers", r"HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components", r"HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\AlternateShell", r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", r"HKLM\System\CurrentControlSet\Control\Session Manager\KnownDlls", r"HKLM\Software\Microsoft\Office\Access\Addins", r"HKLM\Software\Microsoft\Office\Word\Addins", r"HKLM\Software\Microsoft\Office\PowerPoint\Addins", r"HKLM\Software\Microsoft\Office\Excel\Addins", r"HKLM\Software\Microsoft\Office\Outlook\Addins", r"HKCU\Software\Microsoft\Office\Word\Addins", r"HKCU\Software\Microsoft\Office\PowerPoint\Addins", r"HKCU\Software\Microsoft\Office\Excel\Addins"]
    with open(fr'{location}\Persistence_log.md', 'w') as outfile:
        subprocess.call("cmd /c echo REGISTRY KEYS&echo -----------------", stdout=outfile)
        subprocess.call("cmd /c echo[&echo[", stdout=outfile)
        for key in reg_keys:
            print(key)
            out = subprocess.call(f'cmd /c reg query "{key}" /s', stdout=outfile)
            print(str(out))

        subprocess.call("cmd /c echo[&echo[&echo[", stdout=outfile)
        subprocess.call("cmd /c echo START UP FOLDERS:&echo -----------------&echo[", stdout=outfile)
        out_folders = subprocess.call(f'cmd /c dir "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"', stdout=outfile)
        subprocess.call("cmd /c echo[&echo[&echo[", stdout=outfile)
        subprocess.call("cmd /c echo SCHEDULED_TASKS:&echo -----------------&echo[", stdout=outfile)
        out_Schedule = subprocess.call(f'powershell -c "Get-ScheduledTask"', stdout=outfile)

def Processes_and_Services():
    os.system(f'tasklist /svc | find "svchost.exe" >> {location}\Services.md')
    os.system(f'powershell -c "Get-Process >> {location}\Processes.md')


reg()
Processes_and_Services()
make_archive(rf'{location}\Art', 'zip', root_dir=location)

os.system(fr'powershell -c "rm {location}\*.md"')

## Download the file path C:\Windows\Tasks\Artifacts\Art.zip
