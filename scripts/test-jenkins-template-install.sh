#!/bin/sh

#-----------------------------------------------------------------------------
# Global Variables
#-----------------------------------------------------------------------------
export V_FLAG=-v
export OUTPUT_DIR=$(pwd)/out
export LOGS_DIR=${OUTPUT_DIR}/logs
export GOLANGCI_LINT_BIN=${OUTPUT_DIR}/golangci-lint
export PYTHON_VENV_DIR=${OUTPUT_DIR}/venv3
# -- Variables for smoke tests
export TEST_SMOKE_ARTIFACTS=/tmp/artifacts

# -- Setting up the venv
python3 -m venv ${PYTHON_VENV_DIR}
${PYTHON_VENV_DIR}/bin/pip install --upgrade setuptools
${PYTHON_VENV_DIR}/bin/pip install --upgrade pip
# -- Generating a new namespace name
echo "test-namespace-$(uuidgen | tr '[:upper:]' '[:lower:]' | head -c 8)" > ${OUTPUT_DIR}/test-namespace
if [[ $OPENSHIFT_CI == true ]]; then
    # openshift-ci will not allow to create different namespaces, so will do all in the same namespace.
    oc project -q > ${OUTPUT_DIR}/test-namespace
fi
export TEST_NAMESPACE=$(cat ${OUTPUT_DIR}/test-namespace)
echo "Assigning value to variable TEST_NAMESPACE=${TEST_NAMESPACE}"
# -- Do clean up & create namespace
echo "Starting cleanup"
if [[ $OPENSHIFT_CI == true ]]; then
    oc delete all,rolebindings.authorization.openshift.io,bc,cm,is,pvc,sa,secret -l app=jenkins-ephemeral
    oc delete all,rolebindings.authorization.openshift.io,bc,cm,is,pvc,sa,secret -l app=jenkins-persistent
    oc delete all,rolebindings.authorization.openshift.io,bc,cm,is,pvc,sa,secret -l app=openshift-jee-sample
    oc delete all,rolebindings.authorization.openshift.io,bc,cm,is,pvc,sa,secret -l app=jenkins-pipeline-example
else
    kubectl delete namespace ${TEST_NAMESPACE} --timeout=45s --wait
    kubectl create namespace ${TEST_NAMESPACE}
fi
mkdir -p ${LOGS_DIR}/smoke-tests-logs
mkdir -p ${OUTPUT_DIR}/smoke-tests-output
touch ${OUTPUT_DIR}/backups.txt
export TEST_SMOKE_OUTPUT_DIR=${OUTPUT_DIR}/smoke
echo "Logs directory created at "{$LOGS_DIR/smoke}

# -- Setting the project
oc project ${TEST_NAMESPACE}

# -- Trigger the test
echo "Starting local Jenkins instance"
${PYTHON_VENV_DIR}/bin/pip install -q -r smoke/requirements.txt
echo "Running smoke tests in namespace with TEST_NAMESPACE=${TEST_NAMESPACE}"
echo "Logs will be collected in "${TEST_SMOKE_OUTPUT_DIR}
${PYTHON_VENV_DIR}/bin/behave --junit --junit-directory ${TEST_SMOKE_OUTPUT_DIR} \
                              --no-capture --no-capture-stderr \
                              smoke/features -D project_name=${TEST_NAMESPACE}                           
echo "Logs collected in "${TEST_SMOKE_OUTPUT_DIR}
