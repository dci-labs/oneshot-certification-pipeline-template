# Oneshot Certification Template for a new DCI OpenShift project
Follow the requirements described in [the DCI
documentation](https://docs.distributed-ci.io/dci-openshift-agent/#systems-requirements)
to prepare the jumpbox.

## Purpose 
The goal of this repository is to use it when partners try to run `oneshot-certification` when containers and helmcharts test cases need to pass all the sanity checking. This means all container images' verdict statuses from preflight and all test cases from the helm chart report have no failures. However, this repository also provides some DCI Pipeline template settings for certification use cases.

## Instructions

Install the `dci-pipeline` and `dci-openshift-app-agent` rpm on your jumpbox.

Then, create the required directories and files for DCI Pipeline to work:

```ShellSession
$ su - dci-openshift-app-agent
$ cd ~
$ git clone git@github.com:dci-labs/oneshot-certification-pipeline-template.git
$ mv oneshot-certification-pipeline-template to-your-custom-pipeline-name
$ mkdir -p dci-cache-dir upload-errors .config/dci-pipeline
$ cat > .config/dci-pipeline/config <<EOF
PIPELINES_DIR=$HOME/to-your-custom-pipeline-name/pipelines
DEFAULT_QUEUE=pool
EOF
```
**Note:** You can create a git repository name `to-your-custom-pipeline-name` then add, commit and push to github to keep track and maintain changes for next release.  
Another important note is that if this `to-your-custom-pipeline-name` is new pipeline name then you need to update all files from `pipelines/` as well.  
You can do this with one-line script:  
```bash
$ grep -rl 'oneshot-certification-pipeline-template' ./pipelines/ | xargs sed -i 's/oneshot-certification-pipeline-template/to-your-custom-pipeline-name/g'
```

Add the credentials for your remoteci in `~/.config/dci-pipeline/dci_credentials.yml`.

You can now customize the hooks, pipelines and inventories files to meet your needs, following [the DCI documentation](https://docs.distributed-ci.io/).

The custom partner hooks for the `workload` pipeline are in `ocp-workload/hooks` folder.

The inventories are set `dci-queue` to be used with the following settings:

```ShellSession
$ dci-queue add-pool pool
$ dci-queue add-resource pool cluster1
```

## Launching a DCI job with dci-pipeline-schedule

```ShellSession
$ export KUBECONFIG=/var/lib/dci-openshift-app-agent/kubeconfig
```

To run creating container project, update, attach and submit: 

```ShellSession
$ KUBECONFIG=$KUBECONFIG dci-pipeline-schedule create-container-e2e
```

To run only the workload chart-verifer without PR trigger (report.yaml):

```ShellSession
$ KUBECONFIG=$KUBECONFIG dci-pipeline-schedule test-helmchart-nopr
```

Output:
```ShellSession
$ oc -n oneshot get pod -w
NAME                                           READY   STATUS    RESTARTS   AGE
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   0/1     Pending   0          0s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   0/1     Pending   0          0s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   0/1     Pending   0          0s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   0/1     ContainerCreating   0          0s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   0/1     ContainerCreating   0          0s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   1/1     Running             0          2s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   1/1     Terminating         0          2s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   0/1     Terminating         0          4s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   0/1     Terminating         0          5s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   0/1     Terminating         0          5s
yingoneshotchart-4jxey6xop3-756757844c-wv5s8   0/1     Terminating         0          5s

DCI CI Job(finalchart_0_report.yaml):
https://www.distributed-ci.io/jobs/2433c2dd-cde4-40dd-9682-49ea9eef1132/files
```

To run the workload create helmchart project, update and attach PL:

```ShellSession
$ KUBECONFIG=$KUBECONFIG dci-pipeline-schedule create-helmchart
```

To run the workload create openshift-cnf vendor-validate:

```ShellSession
$ KUBECONFIG=$KUBECONFIG dci-pipeline-schedule create-openshift-cnf
```
## How to use parallel feature when test conainter with preflight
To use this parallel feature to run preflight check the containers, there are two parameters that you can use to add them into any DCI Pipeline settings that using `preflight` to check/scan for containers.
You can enable this feature by add them as following:

test containers in parallel:
```yaml
---
- name: test-container-parallel-sanity
  stage: container
  topic: OCP-4.16
  ansible_playbook: /usr/share/dci-openshift-app-agent/dci-openshift-app-agent.yml
  ansible_cfg: ~/oneshot-certification-pipeline-template/pipelines/ansible.cfg
  ansible_inventory: ~/oneshot-certification-pipeline-template/inventories/@QUEUE/@RESOURCE-workload.yml
  dci_credentials: ~/.config/dci-pipeline/dci_credentials.yml
  ansible_skip_tags:
    - post-run
  ansible_extravars:
    dci_cache_dir: ~/dci-cache-dir
    dci_config_dir: ~/oneshot-certification-pipeline-template/ocp-workload
    dci_gits_to_components:
      - ~/oneshot-certification-pipeline-template
    dci_local_log_dir: ~/upload-errors
    dci_tags: ["sanity-check", "submision","preflight","container","async", "parallel"]
    dci_workarounds: []

    # custom setting
    organization_id: 12345678
    page_size: 200

    # docker auth and backend access
    partner_creds: "/var/lib/dci-openshift-app-agent/demo-auth.json"
    pyxis_apikey_path: "/var/lib/dci-openshift-app-agent/demo-pyxis-apikey.txt"

    # reduce the job duration
    do_must_gather: false
    check_workload_api: false
    preflight_test_certified_image: true
    preflight_run_health_check: false

    # test container recertify in parallel
    do_container_parallel_test: true
    max_images_per_batch: 2

    # Define container image tag
    certify_image_tag: "v1"
    preflight_containers_to_certify:
      - container_image: "quay.io/user1/demo-parallel-x1:{{ certify_image_tag }}"
      - container_image: "quay.io/user1/demo-parallel-x2:{{ certify_image_tag }}"
      - container_image: "quay.io/user1/demo-parallel-x3:{{ certify_image_tag }}"
      - container_image: "quay.io/user1/demo-parallel-x4:{{ certify_image_tag }}"
      - container_image: "quay.io/user1/demo-parallel-x5:{{ certify_image_tag }}"
      - container_image: "quay.io/user1/demo-parallel-x6:{{ certify_image_tag }}"
  use_previous_topic: true
  inputs:
    kubeconfig: kubeconfig_path
...
```

Note: You have to becareful with this parameter `max_images_per_batch`, since it requires to determine the Maximum number of images that will allow to run `preflight` check the containers in parallel. 
If you have a physical jumphost BM, then you can define up to `max_images_per_batch: 10`. We tested with `15` when free memory is 55G. 
If you have a VM as DCI machine, then please update as `2-3` images per batch. 

## How to run Oneshot Certification with all green-scenario
In this use-case, it expects all container images and helmchart report.yaml test cases are `PASSED`.
What it is going to do is:
- It creates container projects, update, attach-PL and submit the results to backend
- Wait for all the containers are certified in the catalog using hooks and post-run
- Once oneshot-container stage is passed, then next flow is helmchart
- Similarly to container process, it creates, update, attach-PL and then deploy helmchart CNF and generate reportyaml
- Finally with create_pr is true, then it will copy report.yaml and PR request to charts repo and doing Merge-Request to the production and publish the helm chart

```
$ KUBECONFIG=$KUBECONFIG dci-pipeline-schedule oneshot-container oneshot-helmchart
```

## DCI Pipeline templates info
More template examples are stored [here](https://github.com/dci-labs/oneshot-certification-pipeline-template/tree/main/pipelines)

Final note: If you plan to create any new custom DCI Pipeline settings, and it is not used with `oneshot-certification` use-case, then you must add the following to your new DCI Pipeline setting:
```yaml
  ansible_skip_tags:
    - post-run
```
What it does is, it will skip to hooks that use post-run to wait for the container certification status from the catalog. 
There are examples from other settings in the `pipelines` directory.

