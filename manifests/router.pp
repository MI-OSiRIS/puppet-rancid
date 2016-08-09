# Copyright (C) 2016 OSiRIS Project, funded by the NSF
# Apache License 2.0

# == Define: rancid::router
#
# Create new router definition for rancid in router.db and optionally manage login info in .cloginrc
#
# === Parameters:
#
# [*ensure*] Optional, defaults to 'present'
#			 present or up: put in router.db marked up and put login information in .cloginrc if defined and managed. 
#            absent: delete configuration lines.  
#			 down:  put in config marked down, put login information into .cloginrc if applicable
# [*router*] Optional, defaults to resource name: router hostname or ip
# [*group*] Optional:  Which rancid group associates with router.  Defaults to 'rancid' (default param to rancid class)
# [*type*] Optional:  Router type (dell,cisco,juniper, etc).  Defaults to 'cisco'
# [*enablepass*] Optional: Use as enable password in cloginrc (password param must also be set)
# [*user*] Optional: Add user for router in cloginrc.  
# [*password*] Optional: Add password for router in cloginrc
# [*sshkey*] Optional, defaults to 'false': If true then generate an ssh private key for the router and configure an identity in .cloginrc to use the key.  
#			 Must manually copy .pub key to switch.
# [*method*] Optional, defaults to 'ssh':  Method used to login to the switch, one of 'ssh', 'telnet', or 'rsh'


define rancid::router (
	$ensure = present, 
	$router = $name,
	$group = 'rancid',
	$type = 'cisco',
    $autoenable = false,
	$enablepass = undef,
	$user = undef,
	$password = undef,
	$sshkey = false, 
	$method = 'ssh'
) {

	if ($ensure == 'present') or ($ensure == 'up') {
		$ensure_param = 'present'
		$status = 'up'
	} elsif ($ensure == 'down') {
		$ensure_param = 'present'
		$status = 'down'
	} else {
		$ensure_param = 'absent'
		$status = 'down'
	}

    if ($autoenable == true) { 
        $autoenable_real = '1'
    } else {
        $autoenable_real = '0'
    }
	
    if ($password) { $password_real = $password }
    
    # this will fail if rancid-cvs didn't run and create the file yet
	file_line { "routerdb-$router":
    	path => "${rancid::datadir}/$group/router.db",
    	# require => File['routerdb'],
	    line => "${router};${type};${status}",
    	match => ".*${router}.*$",
    	ensure => $ensure_param
    }

    if ($sshkey) {
    	$keyfile = "${rancid::datadir}/.ssh/${router}.key"
    	file { "${rancid::datadir}/.ssh":
    		ensure => directory,
    		owner => 'rancid',
        	group => 'rancid',
        	mode => '0700',
        	before => Exec['rancid-router-keygen']
    	}

        # need a password line even if using key login (and needed for enable pass on this line if not autoenable)
        if (!$password) { $password_real = 'undef' }

    	exec { 'rancid-router-keygen': 
    		command => "/bin/su - rancid -c \"/usr/bin/ssh-keygen -f $keyfile -N '' -q\"",
    		unless => "/bin/test -f $keyfile"
    	}
    }

    if ($rancid::manage_cloginrc) {
        if ($password_real) {
            $clogin_pass = "$password_real $enablepass"
        } else {
            $clogin_pass = undef
        }

    	$auth_lines = { 'user' => $user, 'password' => $clogin_pass, 'method' => $method, 'identity' => $keyfile, 'autoenable' => $autoenable_real }

    	$auth_lines.each |$line,$value| {
	    	if ($value) {
	    		file_line { "cloginrc-$router-$line":
	    			path => "${rancid::datadir}/.cloginrc",
	    			require => File['cloginrc'],
		    		line => "add $line $router $value",
	    			match => "add ${line}.*${router}.*$",
	    			ensure => $ensure_param
	    		}
	    	}
    	}
    }
}