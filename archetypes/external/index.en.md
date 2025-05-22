+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'external',
 'digitization',
 'business',
 'home',
 'website',
 'iot',
 'networking',
 'smart home',
 'computer',
 'service',
]
# Tags are used for more specific, detailed topics.
tags = [
 'hugo',
 'internet appearance',
 'static website',
 'website design',
 'backup',
 'home assistant',
 'access point',
 'fibre',
 'router',
 'wifi',
 'zigbee',
 'energy',
 'lighting',
 'gardening',
 'solar',
 'linux',
 'mac',
 'windows',
 'maintenance',
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
