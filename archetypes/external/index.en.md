+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'external',
 'side dish',
 'main course',
 'food',
 'team',
 'internal',
 'legal',
 'announcement',
 'product',
]
# Tags are used for more specific, detailed topics.
tags = [
 'kebab',
 'durum',
 'french fries',
 'kebab box',
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
