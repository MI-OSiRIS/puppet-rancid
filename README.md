Puppet module to install rancid and manage configs.  Only tested on RHEL derivatives.  For more information about Rancid please visit the website: http://www.shrubbery.net/rancid/

If using this class with a remote SVN or git repo you must setup passwordless/cached credentials for rancid user to access network repo.
For example: To use github setup a passwordless ssh key under 'rancid' user and add public key to repo.  Login once manually as user to cache the host key. 

This module also installs the following fixes/features:
- an updated 'f10rancid' collector script that works with Dell Z9100 (F10 based switch)
- an updated 'rancid-cvs' script that fixes some issues handling remote git repos

## Class: rancid

Install rancid, setup configuration repository, setup groups and email aliases.  

### Parameters:

[*datadir*] Where the rcs repository is stored (BASEDIR in rancid.conf)

[*logdir*] Optional: Log location.  Defaults to /var/log/rancid.  

[*rcs*] Optional: Revision control system to use.  One of git, svn, or cvs.  Git or Svn can be remote repositories set by rcs_url. Defaults to 'git'. 

[*rcs_url*] Optional: Remote URL for repository.  Only relevant to git or svn.  If not specified a local repo under $datadir/$rcs is used.  Must be in URL form like ssh://github.com/user/repo.git (varies by repo).  
            If it is a remote git repo, the repository must be setup manually as a shared bare repo and rancid-cvs will clone it locally using the URL.  

[*rcs_auth*] Optional:  If set to 'sshkey' we won't try to run rancid-cvs until $datadir/.ssh/id_rsa or id_dsa exists and .ssh/known_hosts exists.  
If there ends up being some problem with auth you can start over by deleting $datadir/$group.  Possible options are 'sshkey' and 'cached', defaults to 'sshkey'

[*manage_cloginrc*] Optional:  Manage .cloginrc with router login info when creating rancid::router resources.  Can be partially managed by not setting all params to router resource (ie, set a user in puppet but manually add password line).

[*groups*] Optional:  Rancid groups and email aliases.  Should be hash of { 'group' => { 'admin' => 'admin_email@domain','diff' => 'diff_email@domain'}.  Default is a group 'rancid' that sends both email reports to root.

## Resource: rancid::router

Create new router definition for rancid in router.db and optionally manage login info in .cloginrc

### Parameters:

[*ensure*] Optional, defaults to 'present'

present or up: put in router.db marked up and put login information in .cloginrc if defined and managed. 

absent: delete configuration lines.  

down:  put in config marked down, put login information into .cloginrc if applicable

[*router*] Optional, defaults to resource name: router hostname or ip

[*group*] Optional:  Which rancid group associates with router.  Defaults to 'rancid' (default param to rancid class)

[*type*] Optional:  Router type (dell,cisco,juniper, etc).  Defaults to 'cisco'

[*enablepass*] Optional: Use as enable password in cloginrc (for this to take effect a password must also be set, or sshkey enabled)

[*user*] Optional: Add user for router in cloginrc.  

[*password*] Optional: Add password for router in cloginrc

[*autoenable*] Optional:  Add setting 'autoenable 1' in cloginrc.  

[*sshkey*] Optional, defaults to 'false': If true then generate an ssh private key for the router and configure an identity in .cloginrc to use the key.  Must manually copy .pub key to switch.
[*method*] Optional, defaults to 'ssh':  Method used to login to the switch, one of 'ssh', 'telnet', or 'rsh'


## Examples:

After this class installs rancid it will notify you to generate an ssh key and configure access to your RCS repository
It checks for id_*sa and known_hosts to verify setup before running rancid-cvs.  If there ends up being some problem with auth you can start over by deleting $datadir/$group(s).   

<pre>
class { '::rancid':
		groups => { 'example' => { 'diff' => 'diff@example.com','admin' => 'admin@example.com'} },
		rcs_url => "ssh://git@github.com/user/rancid.git",
		rcs_auth => 'sshkey',
		rcs => 'git',
		datadir => '/data/rancid',
		manage_cloginrc => true

}
</pre>

Example below of defining a router with a password stored in hiera-eyaml. If instead you set 'sshkey' true then a key will be generated in ${rancid::datadir}/.ssh/<instancename>.key and identity configured in .cloginrc.  It's up to you to copy the .pub portion of the key to your switch

<pre>
rancid::router { 'sw01': 
		group => 'rancid',
		type => 'force10',
		user => 'rancid',
		autoenable => true,
		password => hiera('secret')
}
</pre>
