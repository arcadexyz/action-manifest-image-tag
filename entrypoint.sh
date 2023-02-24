#!/bin/sh
set -e
set -x

if [ -z "$INPUT_DESTINATION_BASE_BRANCH" ]
then
  echo "Destination base branch must be defined."
  return -1
fi

if [ -z "$INPUT_DESTINATION_NEW_BRANCH" ]
then
  echo "Destination new branch must be defined."
  return -1
fi

if [ -z "$INPUT_DESTINATION_FILE_PATH" ]
then
  echo "Destination file path must be defined."
  return -1
fi

if [ -z "$INPUT_GIT_MESSAGE" ]
then
  echo "Git mesage must be defined."
  return -1
fi

export GH_TOKEN=$TOKEN_GITHUB
git config --global --add safe.directory "*"
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

TARGET_DIR=$(mktemp -d)
SHORT_HASH=$(git rev-parse --short HEAD)
HEAD_COMMIT_MSG=$(git show -s --format=%s)
NEW_BRANCH="$SHORT_HASH-$INPUT_DESTINATION_NEW_BRANCH"
TITLE="($SHORT_HASH) $INPUT_GIT_MESSAGE"
COMMIT_LINK="https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
PR_BODY="[$HEAD_COMMIT_MSG]($COMMIT_LINK)"

echo "Cloning target git repo"
git clone "https://$GH_TOKEN@github.com/$INPUT_DESTINATION_REPO.git" "$TARGET_DIR"
cd "$TARGET_DIR"
git checkout -b "$NEW_BRANCH"

echo "Setting new image tag"
sed -ir "s/newtag: [a-zA-Z0-9]\+/newtag: \"$SHORT_HASH\"/g" "$INPUT_DESTINATION_FILE_PATH"

git add $INPUT_DESTINATION_FILE_PATH

if git status | grep -q "Changes to be committed"
then
  echo "Committing changes"
  git commit --message "Update from $COMMIT_LINK: $INPUT_GIT_MESSAGE"

  echo "Pushing git commit"
  git push -u origin HEAD:$NEW_BRANCH

  echo "Creating a pull request"
  gh pr create -t "$TITLE" \
               -b "$PR_BODY" \
               -B $INPUT_DESTINATION_BASE_BRANCH \
               -H $NEW_BRANCH
else
  echo "No changes, noop "
fi

