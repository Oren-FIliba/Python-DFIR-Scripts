import requests
import json
import pandas
import csv

file_path = r'[FULL PATH TO CSV CONTAINING THE IP's]'
IP_CSV = pandas.read_csv((file_path))

ip =IP_CSV['IP'].tolist()


API_KEY = 'API Key for AbuseIPDB'
url = 'https://api.abuseipdb.com/api/v2/check'

csv_columns = ['ipAddress','isPublic','ipVersion','isWhitelisted','abuseConfidenceScore','countryCode','usageType','isp','domain','hostnames','totalReports','numDistinctUsers','lastReportedAt']

headers = {
    'Accept': 'application/json',
    'Key': "API Key for AbuseIPDB"
}
with open(r"D:\Users\suan-orenf\Downloads\AbuseIP_results.csv","a", newline='') as filecsv:
    writer = csv.DictWriter(filecsv, fieldnames=csv_columns)
    writer.writeheader()
for i in ip:
    parameters = {
        'ipAddress': i,
        'maxAgeInDays': '90'}

    response= requests.get( url=url,headers=headers,params=parameters)
    json_Data = json.loads(response.content)
    json_main = json_Data["data"]
    with open(r"D:\Users\suan-orenf\Downloads\AbuseIP_results.csv","a", newline='') as filecsv:
        writer= csv.DictWriter(filecsv,fieldnames=csv_columns)
        writer.writerow(json_main)
        print(json_main)
