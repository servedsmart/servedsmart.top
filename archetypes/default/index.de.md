+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
summary = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'autoreparatur',
 'tuning',
 'mitarbeiter',
 'unternehmensintern',
 'rechtliches',
 'ankündigung',
 'dienstleistung',
]
# Tags are used for more specific, detailed topics.
tags = [
 'autolackierung',
 'folieren',
 'ölwechsel',
 'reifenwechsel',
 'fensterreparatur',
 'bedingungen',
 'bewerben',
]
# Remove this to publish.
draft = true
+++
