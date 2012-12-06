# ThrowAndTell

Automated Error Reporter. Bots, Servers, Monkeys... can automatically open an Issue on [GitHub](https://gihub.com) containing the error's message, stack trace, and any other data may want to fix the bug.

## Usage

This Repo provides the software that acts as a middle-man between your app and GitHub API.

The ThrowAndTell API Docs can be found at ./docs/api/v1.md

## Requirements

* NodeJS (0.8.x) & NPM
* MongoDB Server
* Redis Server

If your not running MongoDB/Redis on localhost without authentication, look at the config section in app.coffee

## Installation

### Download and Install Some of the Dependencies

	git clone https://github.com/bencevans/throwandtell.git
	cd throwandtell
	npm install

### Create a [new GitHub OAuth App](https://github.com/settings/applications/new).

If your planning to just run locally, this is what you need:

* Name = Whatever you like.
* Main URL = http://localhost:3000
* Callback URL = http://localhost:3000/auth/callback

Take note of the Client ID & Secret.

### Start the Server

	GITHUB_CLIENTID=<Insert GitHub Client ID> GITHUB_CLIENTSECRET=<Insert GitHub Client Secret> npm start

### Visit the Site

Open [http://localhost:3000](http://localhost:3000) in your browser.