+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'external',
 'breakfast',
 'sweet pastries',
 'team',
 'internal',
 'legal',
 'announcement',
 'product',
]
# Tags are used for more specific, detailed topics.
tags = [
 'baklava',
 'bread',
 'bread rolls',
 'brownie',
 'croissant',
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
