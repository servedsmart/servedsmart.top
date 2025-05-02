+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
summary = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'starter',
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
 'bruschetta',
 'calzone',
 'garlic bread',
 'pizza',
 'spaghetti',
 'terms',
 'apply',
]
# Remove this to publish.
draft = true
+++
