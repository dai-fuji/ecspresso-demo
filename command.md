デモ 1
ecspresso init --service=ecspresso-demo-service --cluster=ecspresso-demo-cluster

タスク定義修正

ecspresso diff
escpresso deploy

元のタスクセット終了

デモ 2
terraform プラグインによる state

ecspresso.yml に追記

```
plugins:
  - name: tfstate
    config:
      url: s3://ecsdemo-tfstate-fujimoto/ecspresso-demo/terraform.tfstate
      # or path: terraform.tfstate    # path to local file
```

```
    {
      "key": "Name",
      "value": "ecspresso-demo-task-definition"
    }
  ],
  "taskRoleArn": "{{ tfstate `aws_iam_role.ecs_task_role.arn` }}"
}
```

デモ 3
GitHub Actions
