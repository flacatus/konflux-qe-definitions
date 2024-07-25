#!/bin/bash

# Script Name: konflux-it-generator.sh
# Description: Bash CLI to help generate Konflux integration test pipeline YAML.

# Function to display help message
show_help() {
    echo "Usage: $0 [option...] {generate}" >&2
    echo
    echo "   -h, --help            Show help"
    echo "   generate              Generate integration test pipeline YAML"
    echo
    exit 1
}

show_generate_help() {
    echo "Usage: $0 generate --target-dir DIR" >&2
    echo
    echo "   --target-dir DIR  Specify the directory where the YAML will be generated"
    echo
    exit 1
}

generate_yaml() {
    local target_dir=$1

    if [ -z "$target_dir" ]; then
        echo "Error: --target-dir is required"
        show_generate_help
    fi

    if [ ! -d "$target_dir" ]; then
        echo "Error: Directory $target_dir does not exist"
        exit 1
    fi

    if [ ! -w "$target_dir" ]; then
        echo "Error: Directory $target_dir is not writable"
        exit 1
    fi

    local yaml_file="$target_dir/konflux-e2e-tests.yaml"

    echo "Generating integration test pipeline YAML in $yaml_file..."
    cat << EOF > "$yaml_file"
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: konflux-e2e-tests
spec:
  description: |-
    This pipeline automates the process of running end-to-end tests for Konflux
    using a ROSA (Red Hat OpenShift Service on AWS) cluster. The pipeline provisions
    the ROSA cluster, installs Konflux using infra-deployments, runs the tests, collects artifacts,
    and finally deprovisions the ROSA cluster.
  params:
    - name: SNAPSHOT
      description: 'The JSON string representing the snapshot of the application under test.'
      default: '{"components": [{"name":"test-app", "containerImage": "quay.io/example/repo:latest"}]}'
      type: string
    - name: test-name
      description: 'The name of the test corresponding to a defined Konflux integration test.'
      default: ''
    - name: ocp-version
      description: 'The OpenShift version to use for the ephemeral cluster deployment.'
      default: '4.15.9'
      type: string
    - name: test-event-type
      description: 'Indicates if the test is triggered by a Pull Request or Push event.'
      default: 'none'
    - name: region
      description: 'The AWS region to provision the ROSA cluster. Default is us-west-2.'
      default: 'us-west-2'
    - name: aws-secrets
      description: 'The AWS secrets used for provisioning the ROSA cluster.'
      default: 'aws-secrets'
    - name: replicas
      description: 'The number of replicas for the cluster nodes.'
      default: '3'
    - name: machine-type
      description: 'The type of machine to use for the cluster nodes.'
      default: 'm5.2xlarge'
    - name: oras-container
      default: 'quay.io/konflux-ci/konflux-qe-oci-storage'
      description: The ORAS container used to store all test artifacts.
  tasks:
    - name: rosa-hcp-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-metadata/rosa-hcp-metadata.yaml
    - name: test-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/test-metadata/0.1/test-metadata.yaml
      params:
        - name: SNAPSHOT
          value: \$(params.SNAPSHOT)
        - name: oras-container
          value: \$(params.oras-container)
        - name: test-name
          value: \$(context.pipelineRun.name)
    - name: provision-rosa
      when:
        - input: \$(tasks.test-metadata.results.test-event-type)
          operator: in
          values: ["pull_request"]
      runAfter:
        - rosa-hcp-metadata
        - test-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-provision/rosa-hcp-provision.yaml
      params:
        - name: cluster-name
          value: \$(tasks.rosa-hcp-metadata.results.cluster-name)
        - name: ocp-version
          value: \$(params.ocp-version)
        - name: region
          value: \$(params.region)
        - name: replicas
          value: \$(params.replicas)
        - name: machine-type
          value: \$(params.machine-type)
        - name: aws-secrets
          value: \$(params.aws-secrets)
    #
    # Put here the installation and e2e runner task
    #
    #
  finally:
    - name: deprovision-rosa-collect-artifacts
      when:
        - input: \$(tasks.test-metadata.results.test-event-type)
          operator: in
          values: ["pull_request"]
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: test
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-deprovision/rosa-hcp-deprovision.yaml
      params:
        - name: test-name
          value: \$(context.pipelineRun.name)
        - name: ocp-login-command
          value: \$(tasks.provision-rosa.results.ocp-login-command)
        - name: oras-container
          value: \$(tasks.test-metadata.results.oras-container)
        - name: pull-request-author
          value: \$(tasks.test-metadata.results.pull-request-author)
        - name: git-revision
          value: \$(tasks.test-metadata.results.git-revision)
        - name: pull-request-number
          value: \$(tasks.test-metadata.results.pull-request-number)
        - name: git-repo
          value: \$(tasks.test-metadata.results.git-repo)
        - name: git-org
          value: \$(tasks.test-metadata.results.git-org)
        - name: cluster-name
          value: \$(tasks.rosa-hcp-metadata.results.cluster-name)
        - name: region
          value: \$(params.region)
        - name: aws-secrets
          value: \$(params.aws-secrets)
        - name: pipeline-aggregate-status
          value: \$(tasks.status)
EOF
    echo "YAML file generated successfully at $yaml_file"
    exit 0
}

# Parse command line arguments
while [[ "$1" != "" ]]; do
    case $1 in
        -h | --help )
            show_help
            ;;
        generate )
            shift
            if [[ "$1" == "--target-dir" ]]; then
                shift
                generate_yaml "$1"
            else
                echo "Error: --target-dir is required with generate"
                show_generate_help
            fi
            ;;
        * )
            echo "Error: Invalid option"
            show_help
            ;;
    esac
    shift
done

# If no arguments are provided, show help
if [ "$#" -eq 0 ]; then
    show_help
fi
