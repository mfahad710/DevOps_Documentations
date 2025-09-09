# Uninstalling ELK Stack from Ubuntu

If we want to uninstall the ELK stack and its components (Elasticsearch, Logstash, Kibana, Filebeat) from our Ubuntu Server, follow these steps.

**Step 1**  
Stop All Services  
Before uninstalling, stop all related services to ensure that they are not running in the background. Run the following commands:

```bash
sudo systemctl stop elasticsearch
sudo systemctl stop kibana
sudo systemctl stop logstash
sudo systemctl stop filebeat
```

**Step 2**  

Uninstall Elasticsearch  
Remove the Elasticsearch package:
```bash
sudo apt remove --purge elasticsearch
```

Remove Elasticsearch data and configuration directories:

```bash
sudo rm -rf /etc/elasticsearch
sudo rm -rf /var/lib/elasticsearch
sudo rm -rf /var/log/elasticsearch
```

**Step 3**  

Uninstall Kibana
Remove the Kibana package:

```bash
sudo apt remove --purge kibana
```

Remove Kibana data and configuration directories:

```bash
sudo rm -rf /etc/kibana
sudo rm -rf /var/lib/kibana
sudo rm -rf /var/log/kibana
```

**Step 4**  

Uninstall Logstash
Remove the Logstash package:

```bash
sudo apt remove --purge logstash
```

Remove Logstash data and configuration directories:

```bash
sudo rm -rf /etc/logstash
sudo rm -rf /var/lib/logstash
sudo rm -rf /var/log/logstash
```

**Step 5**  

Uninstall Filebeat
Remove the Filebeat package:

```bash
sudo apt remove --purge filebeat
```

Remove Filebeat data and configuration directories:

```bash
sudo rm -rf /etc/filebeat
sudo rm -rf /var/lib/filebeat
sudo rm -rf /var/log/filebeat
```

**Step 6**  

Clean Up Unused Dependencies
After removing the packages, clean up any unused dependencies and residual files:

```bash
sudo apt autoremove
sudo apt autoclean
```

**Step 7**  

Verify Removal
Ensure that no services are still running:

```bash
sudo systemctl list-units --type=service | grep -E 'elasticsearch|kibana|logstash|filebeat'
```

This should return no results.

Check that no related files or directories remain:

```bash
ls /etc/ | grep -E 'elasticsearch|kibana|logstash|filebeat'
ls /var/lib/ | grep -E 'elasticsearch|kibana|logstash|filebeat'
```

**Step 8**  

Optional: Remove Elastic APT Repository
If you no longer need the Elastic repository, remove it:

```bash
sudo rm /etc/apt/sources.list.d/elastic-*.list
sudo apt update
```
