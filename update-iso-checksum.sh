#!/bin/bash
# this will update the alpine.json file with the current image checksum.
set -eu
for json in alpine.json versions/*.json; do
	iso_url=$(jq -r '.iso_url' $json)
	[ "$iso_url" = "null" ] && iso_url=$(jq -r '.variables.iso_url' $json)

	iso_checksum=$(curl -o- --silent --show-error $iso_url.sha256 | awk '{print $1}')
	sed -i -E "s,(\"iso_checksum\": \")([a-f0-9]*)(\"),\\1$iso_checksum\\3,g" $json
	echo "$json: iso_checksum updated successfully"
done
