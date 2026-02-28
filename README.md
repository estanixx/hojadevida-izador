# Hojadevida-izador
An AI powered application to create your CV.


## OIDC Configuration
To configure OIDC for your github, you have to run the following command in your console:
```sh
aws cloudformation deploy\
--template-file infrastructure/github-oidc-provider.yaml \
--stack-name github-actions-oidc \
--capabilities CAPABILITY_NAMED_IAM \
--parameter-overrides GitHubOrg=YOUR_ORG GitHubRepo=YOUR_REPO
```
And then look for the output arn
```sh
aws cloudformation describe-stacks \
--stack-name github-actions-oidc \
--query "Stacks[0].Outputs[?OutputKey=='OIDCRoleArn'].{Key:OutputKey,Value:OutputValue}" \
--output table
```
In github repository secrets include `AWS_ROLE_ARN` and `AWS_REGION`