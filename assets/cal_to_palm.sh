#!/bin/bash
#
# Simple first test to see how feasible it would be to sync calendar dates from
# Apple Calendar to a Palm device.
################################################################################

function convert_date() {
	local epoch=$1
	local base_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "2001-01-01 00:00:00" +"%s")
	local unix_timestamp=$((base_epoch + epoch))
	local offset_seconds=7200
	local adjusted_timestamp=$((unix_timestamp + offset_seconds))
	date -u -r $adjusted_timestamp +"%Y/%m/%d %H%M"
}

date_json=$(icalpal eventsToday+14 -o json all)
#date_json=$(icalpal events -o json all)

temp_file=$(mktemp)

while IFS=$'\t' read -r start_date end_date title; do
	if [[ -n "$start_date" && -n "$end_date" ]]; then
		start_date=$(convert_date "$start_date")
		end_date=$(convert_date "$end_date")
		echo -e "${start_date}\t${end_date}\t\t${title}\n" >>"$temp_file"
	fi
done < <(echo "$date_json" | jq -r '.[] | "\(.start_date)\t\(.end_date)\t\t\(.title)"')

cat "$temp_file"

pilot-install-datebook -p usb: -r "$temp_file"

rm "$temp_file"
