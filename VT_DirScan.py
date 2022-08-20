import requests
import glob
import hashlib
import os


extensions = ["exe", "dll", "lnk"] ## can add any desired extentions 
path = r"C:\Windows\Tasks"
filenames = []
PATH = r"[enter path ]" # [NOTE] : The script will scan recursivly the diroctry 
for ext in extensions:
    filenames_recursive = [y for x in os.walk(PATH) for y in glob.glob(os.path.join(x[0], f'*.{ext}'))]
    for filename in filenames_recursive:
        filenames.append(filename)


print(filenames)
hashes = []
files = []
api_key = '[enter API key for Virus Total]'

with open(f"{path}\VT.md", "w") as vt_file:
    vt_file.write("# Files that were found malicious by Virus total\n")
    vt_file.write("  ----------------------------------------------\n\n")

    for filename in filenames:
        with open(filename, 'rb') as inputfile:
            data = inputfile.read()
            hash = hashlib.sha256(data).hexdigest()
            print(hash)

            try:
                #print(hash)
                r = requests.get(f"https://www.virustotal.com/api/v3/files/{hash}", headers={'user-agent':'Mozilla/5.0 (x11; Linux x86_64; rv:61.0) Gecko/20100101 Firefox/61.0','x-apikey': f'{api_key}'}).json()
                #print(r)
                dict_web = r["data"]["attributes"]["last_analysis_results"]
                tot_engine_c = 0
                tot_detect_c = 0
                result_eng = []
                eng_name = []
                count_harmless = 0
                for i in dict_web:
                    tot_engine_c = 1 + tot_engine_c
                    if dict_web[i]["category"] == "malicious" or dict_web[i]["category"] == "suspicious":
                        result_eng.append(dict_web[i]['result'])
                        eng_name.append(dict_web[i]["engine_name"])
                        tot_detect_c = 1 + tot_detect_c
                res = []
                for i in result_eng:
                    if i not in res:
                        res.append(i)
                result_eng = res
                if tot_detect_c > 0:
                    #print(result_eng[0])
                    vt_file.write(f"## {filename} :\n\n```js\n       * hash: {hash}\n       * Verdict - Malicious\Suspicious\n       * Detections - {str(tot_detect_c)} engines\n       * Possible {result_eng[0:3]}\n```\n\n" )


            except:
                print(r['error']['message'])
                continue
