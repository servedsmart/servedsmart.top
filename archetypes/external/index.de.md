+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'extern',
 'vorspeise',
 'hauptspeise',
 'lebensmittel',
 'mitarbeiter',
 'unternehmensintern',
 'rechtliches',
 'ankündigung',
 'produkt',
]
# Tags are used for more specific, detailed topics.
tags = [
 'bruschetta',
 'calzone',
 'knoblauchbrot',
 'pizza',
 'spaghetti',
 'bedingungen',
 'bewerben',
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
