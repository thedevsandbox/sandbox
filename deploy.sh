#! /bin/bash

echo "Installing serverless"
echo "_______________________________"

npm install -g serverless

echo "Deploying to $env"
echo "_______________________________"
serverless deploy --stage $env --package $CODEBUILD_SRC_DIR/artifacts/$env -v