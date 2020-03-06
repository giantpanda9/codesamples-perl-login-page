#!/usr/bin/perl
use strict 'vars';
use warnings;
use CGI;
use DBI;
use Data::Dumper;
my $cgi = CGI->new();
my $out = "";
my $action = $cgi->param('action') || $cgi->param('redirect') || "main";
use CGI::Cookie;
#This script will provide access to the secret page with Perl automatically genrating pages
if ($action eq "main") {
	$out = <<EOF;


<HTML>
<HEAD>
<TITLE>TEST PAGE</TITLE>
</HEAD>
<BODY>
<p>You need to register to access secret page</p>
<p> Please register here: <a href="./test.pl?action=register">REGISTER</a></p>
<p> Please login here: <a href="./test.pl?action=login">LOG IN</a></p>
</BODY>
</HTML>
EOF
} elsif ($action eq "register") {
	$out = <<EOF;
<HTML>
<HEAD>
<TITLE>TEST PAGE</TITLE>
</HEAD>
<BODY>
<p>Please register here</p>
<p>Or return to main page: <a href="./test.pl">RETURN</a></p>
<p id="errors"></p>
<form id="register" mathod = "POST" action="./test.pl?action=saveuser">
  Login: <input type="name" id="name" required><br><br>
  Password: <input type="pass" id="pass" required><br><br>  
  <input type="submit" value="Register">
</form>

<script>
const register = document.getElementById('register');
const name = document.getElementById('name');
const pass = document.getElementById('pass');

register.addEventListener('submit', function (event) {
	event.preventDefault();
	var error = "";
	
	if (/^\\d/.test(name.value)) {
		error += "Login must not start with number<br>";
	}
	if ((name.value).length < 3) {
		error += "Login must be greater than 3 characters<br>";
	}
	if ((pass.value).length < 3) {
		error += "Password must be greater than 3 characters<br>";
	}
	if (error == "") {	
		window.location = './test.pl?action=saveuser;name=' + name.value + ';pass=' + pass.value;
	} else {
		document.getElementById("errors").innerHTML = error;
	}
});
</script>
</BODY>
</HTML>
EOF
} elsif ($action eq "login") {	
	my %cookies = fetch CGI::Cookie;
	if (exists($cookies{'name'}) && exists($cookies{'pass'}) && $cookies{'name'} && $cookies{'pass'}) {
		my $cname = $cookies{'name'}->value;
		my $cpass = $cookies{'pass'}->value;
		if (($cname) && ($cpass)) {
			my $allowed = check($cname, $cpass);
			if ($allowed) {
				setlastlogin($cookies{'name'}->value);
				print "Location:./test.pl?action=secretpage\n\n"; 
			}
		}
	}
	$out = $cgi->start_html('TEST PAGE');
	$out .= $cgi->start_form(
        -name    => 'main_form',
        -method  => 'POST',
        -enctype => &CGI::URL_ENCODED,
        -onsubmit => '',
        -action => './test.pl?action=checkaccess', 
    );
    $out .= $cgi->p('Username/Password:');
    $out .= $cgi->textfield(
        -name      => 'name',
        -value     => '',
        -size      => 20,
        -maxlength => 30,
        -required => 1,
    );
    $out.=$cgi->hidden(
        -name      => 'redirect',
        -default   => 'checkaccess',
    );
    $out .= $cgi->textfield(
        -name      => 'pass',
        -value     => '',
        -size      => 20,
        -maxlength => 30,
        -required => 1,
    );
 
    $out .= $cgi->submit(
        -name     => 'submit',
        -value    => 'login',        
    );
    $out .=  $cgi->end_form;

} elsif ($action eq "secretpage") {
	$out = <<EOF;
<HTML>
<HEAD>
<TITLE>TEST PAGE</TITLE>
</HEAD>
<BODY>
<p> Welcome to Secret Page </p>
<p>Return to main page: <a href="./test.pl">RETURN</a></p>
<p>Logout: <a href="./test.pl?action=logout">LOGOUT</a></p>
</BODY>
</HTML>
EOF
} elsif ($action eq "logout") {
my %cookies = fetch CGI::Cookie;
	# Get rid of cookies to log off
	if (exists($cookies{'name'}) && exists($cookies{'pass'}) && $cookies{'name'} && $cookies{'pass'}) { # Get rid of old cookies
		my $cookie1 = $cgi->cookie(-name=>'name',
    -value=>$cookies{'name'}->value,
    -expires=>'-10y',
    -path=>'/');
		my $cookie2 = $cgi->cookie(-name=>'pass',
    -value=>$cookies{'pass'}->value,
    -expires=>'-10y',
    -path=>'/');
		print $cgi->header(-cookie=>[$cookie1,$cookie2]);
		print qq~<meta http-equiv="refresh" content="0;URL=./test.pl?action=logout">\n~;
	}
$out = <<EOF;
<HTML>
<HEAD>
<TITLE>TEST PAGE</TITLE>
</HEAD>
<BODY>
<p> You logged off from Secret Page </p>
<p>Return to main page: <a href="./test.pl">RETURN</a></p>
</BODY>
</HTML>
EOF
} elsif ($action eq "notallowed") {
	$out = <<EOF;
<HTML>
<HEAD>
<TITLE>TEST PAGE</TITLE>
</HEAD>
<BODY>
<p> You are not allowed to see Secret Page - please try again or register </p>
<p>Return to main page: <a href="./test.pl">RETURN</a></p>

</BODY>
</HTML>
EOF
} elsif ($action eq "checkaccess") {
	my $name = $cgi->param('name');
	my $pass =  $cgi->param('pass');
	
	my $allowed = check($name, $pass);
	if ($allowed) {
		setlastlogin($name);
		my $cookie1 = $cgi->cookie(-name=>'name',
    -value=>$name,
    -expires=>'+4h',
    -path=>'/');
		my $cookie2 = $cgi->cookie(-name=>'pass',
    -value=>$pass,
    -expires=>'+4h',
    -path=>'/');
		print $cgi->header(-cookie=>[$cookie1,$cookie2]);
		print qq~<meta http-equiv="refresh" content="0;URL=./test.pl?action=secretpage">\n~;
		print "Location: ./test.pl?action=secretpage\n\n"; 
	} else {
		print "Location: ./test.pl?action=notallowed\n\n"; 
	}

} elsif ($action eq "saveuser") {
	my $name = $cgi->param('name');
	my $pass = $cgi->param('pass');	
	my $userdata = getpassbyname($name);
	my $result;
	# Check if user exists
	if ($userdata) { # And if so update the password
		updatedbentry($name, $pass);		
		my %cookies = fetch CGI::Cookie;
		if (exists($cookies{'name'}) && exists($cookies{'pass'}) && $cookies{'name'} && $cookies{'pass'}) { # Get rid of old cookies
			my $cookie1 = $cgi->cookie(-name=>'name',
    -value=>$name,
    -expires=>'-10y',
    -path=>'/');
			my $cookie2 = $cgi->cookie(-name=>'pass',
    -value=>$pass,
    -expires=>'-10y',
    -path=>'/');
			print $cgi->header(-cookie=>[$cookie1,$cookie2]);
			print qq~<meta http-equiv="refresh" content="0;URL=./test.pl?action=saveuser">\n~;
		}
	} else { # If not add the user
		createdbentry($name, $pass);
	}

	$out = <<EOF;
<HTML>
<HEAD>
<TITLE>TEST PAGE</TITLE>
</HEAD>
<BODY>
<p> Registration complete </p>
<p>Return to main page: <a href="./test.pl">RETURN</a></p>

</BODY>
</HTML>
EOF

}
print "Content-type:text/html\n\n";  
print $out . "\n\n";

sub check { # Check if user allowed to access the Secret Page
	my $name=shift;
	my $pass=shift;
	my $userdata = getpassbyname($name);
	return if (!$userdata);
	if ($userdata eq $pass) {
		return 1;
	} else {
		return 0;
	}
	return;
}

sub updatedbentry { # Update entry if user exists
	
	my $name=shift;
	my $pass=shift;
	my $myConnection = DBI->connect("DBI:Pg:dbname=testdb;host=localhost", "testuser", "testpassword");
	
	my $query = $myConnection->prepare("UPDATE testusers SET pass=" . $myConnection->quote( $pass ) . " WHERE name=" . $myConnection->quote( $name ));
	my $result = $query->execute();
	$myConnection->disconnect;
	return;
	
}

sub createdbentry { # Add user if not present in Database
	
	my $name=shift;
	my $pass=shift;
	my $myConnection = DBI->connect("DBI:Pg:dbname=testdb;host=localhost", "testuser", "testpassword");
	
	my $query = $myConnection->prepare("INSERT INTO testusers (name,pass) VALUES (?,?)");
	my $result = $query->execute($name, $pass);
	$myConnection->disconnect;
	return;
	
}

sub getpassbyname { # Sub checks if user exists in DB and if so returns a password

	my $name = shift;
	
	my $myConnection = DBI->connect("DBI:Pg:dbname=testdb;host=localhost", "testuser", "testpassword");
	
	my $query = $myConnection->prepare("SELECT pass FROM testusers WHERE name=" . $myConnection->quote( $name ));
	my $result = $query->execute();
	if ($result != '0E0') {
		while (my $item = $query->fetchrow_hashref) {
			my $pass = $item->{pass};		
			return $pass;
		}
	}
	$myConnection->disconnect;
	return;
	
}

sub setlastlogin {

	my $name = shift;
	
	my $myConnection = DBI->connect("DBI:Pg:dbname=testdb;host=localhost", "testuser", "testpassword");
	
	my $query = $myConnection->prepare("UPDATE testusers SET lastlogin=CURRENT_DATE WHERE name=" . $myConnection->quote( $name ));
	my $result = $query->execute();
	$myConnection->disconnect;
	
}
