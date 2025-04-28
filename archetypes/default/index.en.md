+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
summary = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'car repair',
 'tuning',
 'team',
 'internal',
 'legal',
 'announcement',
 'service',
]
# Tags are used for more specific, detailed topics.
tags = [
 'car painting',
 'car wrapping',
 'oil change',
 'tire change',
 'window repair',
 'terms',
 'apply',
]
# Remove this to publish.
draft = true
+++
