+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'alcohol',
 'beverages',
 'food',
 'team',
 'internal',
 'legal',
 'announcement',
 'product',
]
# Tags are used for more specific, detailed topics.
tags = [
 'beer',
 'chocolate',
 'milk shake',
 'potato chips',
 'rum',
 'terms',
 'apply',
]
# Remove this to publish.
draft = true
+++
