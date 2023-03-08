#!/usr/bin/env bash
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd $SCRIPTPATH
cd ../../../
. config.profile

# check the enviroment info
nvidia-smi
#${PYTHON} -m pip install yacs
#${PYTHON} -m pip install torchcontrib
#${PYTHON} -m pip install git+https://github.com/lucasb-eyer/pydensecrf.git

export PYTHONPATH="$PWD":$PYTHONPATH

DATA_ROOT="$PWD/data"
DATA_DIR="${DATA_ROOT}/ade20k"
SAVE_DIR="${DATA_ROOT}/seg_result/ade20k/"
BACKBONE="hrnet48"
CONFIGS="configs/ade20k/H_48_D_4.json"
CONFIGS_TEST="configs/ade20k/H_48_D_4_TEST.json"

MODEL_NAME="hrnet_w48"
LOSS_TYPE="fs_ce_loss"
CHECKPOINTS_NAME="${MODEL_NAME}_${BACKBONE}_"$2
PRETRAINED_MODEL="./pretrained/hrnetv2_w48_imagenet_pretrained.pth"
MAX_ITERS=150000
SIGMA=0.002

LOG_FILE="./log/ade20k/${CHECKPOINTS_NAME}.log"
echo "Logging to $LOG_FILE"
mkdir -p `dirname $LOG_FILE`

if [ "$1"x == "train"x ]; then
  python3 -u main.py --configs ${CONFIGS} \
                       --drop_last y \
                       --phase train \
                       --gathered n \
                       --loss_balance y \
                       --log_to_file n \
                       --backbone ${BACKBONE} \
                       --model_name ${MODEL_NAME} \
                       --gpu 0 1 2 3 \
                       --data_dir ${DATA_DIR} \
                       --loss_type ${LOSS_TYPE} \
                       --max_iters ${MAX_ITERS} \
                       --checkpoints_name ${CHECKPOINTS_NAME} \
                       --pretrained ${PRETRAINED_MODEL} \
                       --nbb_mult 1.0 \
                       --sigma ${SIGMA} \
                       2>&1 | tee ${LOG_FILE}
                       

elif [ "$1"x == "resume"x ]; then
  python3 -u main.py --configs ${CONFIGS} \
                       --drop_last y \
                       --phase train \
                       --gathered n \
                       --loss_balance y \
                       --log_to_file n \
                       --backbone ${BACKBONE} \
                       --model_name ${MODEL_NAME} \
                       --max_iters ${MAX_ITERS} \
                       --data_dir ${DATA_DIR} \
                       --loss_type ${LOSS_TYPE} \
                       --gpu 0 1 2 3 \
                       --resume_continue y \
                       --resume ./checkpoints/ade20k/${CHECKPOINTS_NAME}_latest.pth \
                       --checkpoints_name ${CHECKPOINTS_NAME} \
                       --sigma ${SIGMA} \
                       2>&1 | tee -a ${LOG_FILE}

elif [ "$1"x == "val"x ]; then
   python3 -u main.py --configs ${CONFIGS} \
                        --data_dir ${DATA_DIR} \
                        --backbone ${BACKBONE} \
                        --model_name ${MODEL_NAME} \
                        --checkpoints_name ${CHECKPOINTS_NAME} \
                        --phase test \
                        --gpu 0 \
                        --val_batch_size 1 \
                        --resume ./checkpoints/ade20k/${CHECKPOINTS_NAME}_max_performance.pth \
                        --test_dir ${DATA_DIR}/val/image \
                        --log_to_file n --sigma ${SIGMA} \
                        --out_dir ${SAVE_DIR}${CHECKPOINTS_NAME}_val

  cd lib/metrics
  python3 -u ade20k_evaluator.py --configs ../../${CONFIGS} \
                                   --pred_dir ${SAVE_DIR}${CHECKPOINTS_NAME}_val/label \
                                   --gt_dir ${DATA_DIR}/val/label

elif [ "$1"x == "test"x ]; then
  python3 -u main.py --configs ${CONFIGS} \
                       --backbone ${BACKBONE} --model_name ${MODEL_NAME} --checkpoints_name ${CHECKPOINTS_NAME} \
                       --phase test --gpu 0 --resume ./checkpoints/ade20k/${CHECKPOINTS_NAME}_latest.pth \
                       --test_dir ${DATA_DIR}/test --log_to_file n --out_dir test 2>&1 | tee -a ${LOG_FILE}

else
  echo "$1"x" is invalid..."
fi
