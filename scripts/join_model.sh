#!/usr/bin/env bash
set -euo pipefail

#/ Usage: bash prepare_data.sh
#/ Description: Prepares the data for the experiment.
#/ Examples: bash clip_helper.sh 10003_20706_alv_A.flac 10003_20706_alv_A.tab data/train/snippets
#/ Options:
#/   --help: Display this help message
usage() { grep '^#/' "$0" | cut -c4- ; exit 0 ; }
expr "$*" : ".*--help" > /dev/null && usage

locate_self() {
	# Locate this script.
	readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	readonly PARENT_DIR="$SCRIPT_DIR"/..
}

# Prevent execution when sourcing this script
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
	locate_self
	cd $PARENT_DIR
	export LC_ALL=C
	source ./cmd.sh
	source ./path.sh

	train_cmd="utils/run.pl"
	nj=12

	channels="A B C D E F G H src"
	used_classes="NS NT S"

	for class in $used_classes; do
		mkdir -p $class/all
		for channel in $channels; do
			if [ $class == "NT" ]; then
				if [ $channel == "G" ] || [ $channel == "src" ]; then
					continue
				fi
			fi
			cat $class/$channel/wav.scp | sed -i -e "s/^/${channel}_" >> $class/all/wav.scp1
			cat $class/$channels/feats.scp | sed -i -e "s/^/${channel}_" >> $class/all/feats.scp1
			cat $class/$channels/vad.scp | sed -i -e "s/^/${channel}_" >> $class/all/vad.scp1
			cat $class/$channel/utt2spk | sed -i -e "s/$class/${channel}_${class}" >> $class/all/utt2spk1
		done

		cat $class/all/wav.scp1 | sort > $class/all/wav.scp
		cat $class/all/feats.scp1 | sort > $class/all/feats.scp
		cat $class/all/vad.scp1 | sort > $class/all/vad.scp
		cat $class/all/utt2spk1 | sort > $class/all/utt2spk
		./utils/utt2spk_to_spk2utt.pl $class/all/utt2spk > $class/all/spk2utt
		bash utils/validate_data_dir.sh --no-text $class/all

		sid/train_diag_ubm.sh --nj $nj --cmd "$train_cmd" --delta-window 2 \
			$class/all 32 exp/diag_ubm_${class}_all
		
		sid/train_full_ubm.sh --nj $nj --cmd "$train_cmd" \
			--remove-low-count-gaussians false $class/all \
			exp/diag_ubm_${class}_all exp/full_ubm_${class}_all
	done
fi




