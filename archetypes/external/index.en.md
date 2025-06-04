+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'external',
 'furniture',
 'construction',
 'team',
 'internal',
 'legal',
 'announcement',
 'service',
]
# Tags are used for more specific, detailed topics.
tags = [
 'end table',
 'repainting',
 'door',
 'staircase',
 'window frame',
 'terms',
 'apply',
]
# Remove this to publish.
draft = true
# External URL specific parameters
externalUrl = ""
showReadingTime = false
[build]
render = "false"
list = "local"
+++
