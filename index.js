// Copyright (c) 2020-2022 MSP-Greg

'use strict';

const cp          = require('child_process')
const core        = require('@actions/core')
const { Octokit } = require('@octokit/rest')
const { retry }   = require('@octokit/plugin-retry')

const tarExt = '.7z'

// returns updated release body
const updateBody = (releaseBody, releaseName) => {
  const re = new RegExp('^\\*\\*' + releaseName + ':\\*\\* ([^\\r]+)', 'm')
  // (match, p1, p2, offset, str)
  return releaseBody.replace(re, () => `**${releaseName}:** 7z package   Run No: ${process.env.GITHUB_RUN_NUMBER}`)
}

const run = async () => {
  try {

    const releaseTag  = core.getInput('release_tag' , { required: true });
    const releaseName = core.getInput('release_name', { required: true });

    const gccTar = `${releaseName}${tarExt}`

    console.time('  Upload 7z')

    const cmd = `gh release upload ${releaseTag} ${gccTar} --clobber`

    console.log(`[command]${cmd}`)
    cp.execSync(cmd, {stdio: ['ignore', 'inherit', 'inherit']})

    console.timeEnd('  Upload 7z')

    // wait for file processing
    await new Promise(r => setTimeout(r, 5000))

    // Get owner and repo from context of payload that triggered the action
    const [ owner, repo ] = process.env.GITHUB_REPOSITORY.split('/')

    const MyOctokit = Octokit.plugin(retry)

    const octokit = new MyOctokit({
      auth: process.env.GITHUB_TOKEN,
      userAgent: `${owner}--${repo}`,
      timeZone: 'America/Chicago'
    })

    console.time('Update Info')

    // Get releaseId and Release body
    const {data: { body: releaseBody, id: releaseId }
    } = await octokit.repos.getReleaseByTag({
      owner: owner,
      repo: repo,
      tag: releaseTag
    })

    // Update Release body
    // https://octokit.github.io/rest.js/v18#repos-update-release-asset
    await octokit.repos.updateRelease({
      owner: owner,
      repo: repo,
      release_id: releaseId,
      body: updateBody(releaseBody, releaseName)
    })

    console.timeEnd('Update Info')

  } catch (error) {
    core.setFailed(error.message)
  }
}

run()
