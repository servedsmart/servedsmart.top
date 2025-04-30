+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
summary = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'extern',
 'frühstück',
 'süßes gebäck',
 'mitarbeiter',
 'unternehmensintern',
 'rechtliches',
 'ankündigung',
 'produkt',
]
# Tags are used for more specific, detailed topics.
tags = [
 'baklava',
 'brot',
 'brötchen',
 'brownie',
 'croissant',
 'bedingungen',
 'bewerben',
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
