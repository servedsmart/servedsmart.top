+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
summary = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'breakfast',
 'sweet pastries',
 'food',
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
+++
