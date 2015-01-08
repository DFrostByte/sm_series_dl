#!/bin/bash

###############################################################################
# Functions
###############################################################################

function _log_err_
{
	local err_file='err.log'

	echo "$@" >> "$err_file"
}

function _log_
{
	local file='log'

	echo "$@" >> "$file"
}

function _wget_
{
	local useragent="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:28.0) Gecko/20100101 Firefox/28.0"

	wget --user-agent="$useragent" "$@"
}

function _wget_stdout_
{
	_wget_ -O - "$@"
}

function _gen_filename_
{
	local series_title="$1"
	local season="$2"
	local ep_num="$3"
	local ep_title="$4"
	local ext="$5"

	if [ -z "$ext" ]
	then
		ext='mp4'
	fi

	echo "${series_title}-${season}x${ep_num}-${ep_title}.${ext}"
}

function _gen_episode_url_
{
	local series="$1"
	local season="$2"
	local epnum="$3"

	local base_url='http://www.solarmovie.is/tv/'

	echo "${base_url}${series}/season-${season}/episode-${epnum}/"
}

function _grep_one_
{
	grep --max-count=1 "$@"
}

function _ep_title_from_html_
{
	local html_str="$1"
	local title=''

	echo "$html_str" | _grep_one_ "<title>" | \
	                   cut -d '-' -f2,4     | \
	                   sed 's/^\s*//'
}

function _linkid_from_ep_html_
{
	local html_str="$1"

	echo "$html_str" | _grep_one_ --after-context=1 "vodlocker" | \
	                   _grep_one_ "/link/show"                  | \
	                   cut -d '/' -f4
}

function _get_play_frame_html_
{
	local link_id="$1"

	_wget_stdout_ "solarmovie.is/link/play/${link_id}/"
}

function _embed_url_from_frame_
{
	local html_str="$1"

	echo "$html_str" | _grep_one_ "FRAME SRC" | \
	                   cut -d '"' -f2
}

function _file_url_from_dl_page_
{
	local html_str="$1"

	echo "$pagestr" | _grep_one_ "file:" | \
	                  cut -d '"' -f2
}

function _try_download_ep_
{
	local series="$1"  #eg south-park-1997
	local season="$2"
	local epnum="$3"

	local ep_url="$(_gen_episode_url_ "$series" "$season" "$epnum")"
	local pagestr="$(_wget_stdout_ "$ep_url")"
	if [ $? -eq 0 ]
	then
		local eptitle="$(_ep_title_from_html_ "$pagestr")"
		local linkid="$(_linkid_from_ep_html_ "$pagestr")"

		# episode play frame
		pagestr="$(_get_play_frame_html_ "$linkid")"
		if [ $? -eq 0 ]
		then
			local dl_page_url="$(_embed_url_from_frame_ "$pagestr")"

			pagestr="$(_wget_stdout_ "$dl_page_url")"
			if [ $? -eq 0 ]
			then
				local fileurl="$(_file_url_from_dl_page_ "$pagestr")"
				local filename="$(_gen_filename_ "$series" "$season" "$epnum" "$eptitle" 'mp4')"

				if _wget_ -O "$filename" "$fileurl"
				then
					true
				fi
				_log_err_ "<${fileurl}> $series $season x $epnum"
			fi
			_log_err_ "<${dl_page_url}> $series $season x $epnum"
		fi
		_log_err_ "<Play Frame> $series $season x $epnum"
	fi
	_log_err_ "<${ep_url}> $series $season x $epnum"

	false
}

###############################################################################
# Main
###############################################################################

_series='south-park-1997'
_max_epnum=25

for season in {3..18}
do
	for ((epnum=1; $epnum < $_max_epnum; epnum++))
	do
		for ((attempts=10; $attempts > 0; attempts--))
		do
			if _try_download_ep_ "$_series" "$season" "$epnum"
			then
				_log_ "downloaded=${series}-${season}x${epnum}"
				break
			fi
		done
	done
done







