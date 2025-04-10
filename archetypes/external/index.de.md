+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
summary = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'extern',
 'digitalisierung',
 'unternehmen',
 'heimkunden',
 'website',
 'iot',
 'netzwerk',
 'smart home',
 'computer',
 'dienstleistung',
]
# Tags are used for more specific, detailed topics.
tags = [
 'hugo',
 'internetauftritt',
 'statische website',
 'website design',
 'backup',
 'home assistant',
 'access point',
 'glasfaser',
 'router',
 'wifi',
 'wlan',
 'zigbee',
 'energie',
 'licht',
 'pflanzen',
 'solar',
 'linux',
 'mac',
 'windows',
 'wartung',
]
# Remove this to publish.
draft = true
# External URL specific parameters
externalUrl = ""
showReadingTime = false
[_build]
render = "false"
list = "local"
+++
