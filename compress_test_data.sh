FRAME_ID=${1}
SRC_PLY=../WPI_LidarData/TestData/${FRAME_ID}.ply
SRC_NAME=${FRAME_ID}
DRACO_ROOT=/home/tianqiu/Documents/Draco_test/draco/build
for CL in 3 5 7 10
do
	EXP_DIR=../WPI_LidarData/CompressedTestData/geom_and_attr
	LOG_NAME=${EXP_DIR}/log/${SRC_NAME}_cl_${CL}.log
		${DRACO_ROOT}/draco_encoder -point_cloud -i ${SRC_PLY} -cl ${CL} -qp 11 -qt 10 -qg 8 -o ${EXP_DIR}/encoded_drc/${SRC_NAME}_cl_${CL}.drc > ${LOG_NAME}
		${DRACO_ROOT}/draco_decoder -i ${EXP_DIR}/encoded_drc/${SRC_NAME}_cl_${CL}.drc -o ${EXP_DIR}/decoded_ply/${SRC_NAME}_cl_${CL}_decoded.ply >> ${LOG_NAME}
done
