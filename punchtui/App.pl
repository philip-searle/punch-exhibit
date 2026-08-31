#!/usr/bin/perl

# Add script directory to @INC
use FindBin;
use lib "$FindBin::Bin";

use Modern::Perl;
use Curses::UI;
use Curses;
use Device::SerialPort;
use Try::Tiny;
use CCH::PunchExhibit::Fonts;

my $port_name = '/dev/ttyUSB0';
my $baud_rate = 110;
my $credits = 0;

my $cui = Curses::UI->new(
	-clear_on_exit => 0,
	-color_support => 1,
	-debug => 0
);

my $status_window = $cui->add(
	'status_window', 'Window',
	-x => 0, -y => 0,
	-width => 80, -height => 2
);

my $kbprompt = $status_window->add(
	'kbprompt', 'Label',
	-x => 60, -y => 0,
	-width => 20, -height => 1,
	-text => "WAIT",
	-fg => 'blue', -bold => 1,
	-textalignment => 'right'
);

my $submenu = [
	{ -label => 'Add credit', -value => sub {
			update_credits($credits + 1);
			open_menu();
		}
	},
	{ -label => 'Toggle free play', -value => sub {
			update_credits($credits < 0 ? 0 : -1);
			open_menu();
		}
	},
	{ -label => 'Leave service mode', -value => sub { } },
	{ -label => 'Punch test tape', -value => sub {
			do_punch_internal(
				'JACKDAWS LOVE MY BIG SPHINX OF QUARTZ 0123456789 ,.<>/?@#~[]!"$()'
			);
			open_menu();
		}
	},
	{ -label => 'Exit program', -value => sub { exit; } }
];

my $menu_data = [
	{ -label => "CTRL-P=Service Menu", -submenu => $submenu }
];

my $menubar = $status_window->add(
	'menubar', 'Menubar',
	-menu => $menu_data,
	-bg => 'black', -fg => 'white'
);
# Bodge internal state so menu bar isn't full width
$menubar->{-width} = 25;
$menubar->layout;

my $punch_win = $cui->add(
	'punch_window', 'CCH::PunchExhibit::PunchWindow',
	-border => 0,
	-x => 0, -y => 2,
	-width => 80, -height => 23,
	-onenter => \&do_punch
);

my $coin_win = $cui->add(
	'coin_win', 'CCH::PunchExhibit::CoinWindow',
	-border => 0,
	-x => 0, -y => 2,
	-width => 80, -height => 23
);

sub open_menu {
	#$menubar->modalfocus;
	#$menubar->pulldown;
}

sub close_menu {
	$punch_win->focus();
}

$cui->set_binding(sub {$cui->mainloopExit;}, "\cC");
$cui->set_binding(sub {
		my $dialog = $cui->add(
			'mydialog', 'Dialog::Question',
			-title => 'Service Menu Access',
			-question   => 'Enter password:',
			-buttons => [ 'ok' ],
			-titleinverse => 1
		);
		$dialog->getobj('answer')->{-password} = '*';
		$dialog->modalfocus;
		my $password = $dialog->get;
		$cui->delete('mydialog'); 
		if ($password eq 'egg') {
			$menubar->focus();
		} else {
			$cui->error(-message => 'Incorrect password',-fg => 'red');
		}
	}, "\cP");
update_credits(0);
$cui->mainloop;

sub do_punch {
	my $namefield = shift;
	do_punch_internal($namefield->text);
	$namefield->text('');
	update_credits($credits - 1);
}

sub do_punch_internal {
	my $text = shift;

	try {
		my $bauds_per_char =
			(1 + 5 + 1) * # max two bin chars, five 5x5 chars, one sep
			(1 + 5 + 2);  # start bit, data bits, stop bits
		my $total_bauds = $bauds_per_char * length($text);

		$cui->progress(
			-max => $total_bauds,
			-message => 'Pull tape upwards when punching finishes'
		);
		$cui->setprogress(1);

		# Bodge because Device::SerialPort sometimes doesn't set the config?
		`stty -F $port_name $baud_rate -parenb cs5 2>&1 >/dev/null`;
		$cui->setprogress($baud_rate);

		my $start_time = time();
		punch_souvenir($text);
		my $end_time = time();
		for (my $progress = ($end_time - $start_time) * $baud_rate; $progress < $total_bauds; $progress += $baud_rate) {
			$cui->setprogress($progress);
			sleep 1;
		}
		$cui->setprogress($total_bauds);
		sleep 1;
		$cui->dialog(-title => 'Punching complete!', -message => "Pull the tape upwards to tear it off.");
	} catch {
		$cui->error(-message => "Failed to punch; cause was:\n$_");
	} finally {
		$cui->noprogress;
		$cui->draw();
	}
}

sub punch_souvenir {
	my $text = shift;

	my $port = Device::SerialPort->new($port_name) || die "Can't open $port_name: $!\n";
	$port->baudrate($baud_rate);
	$port->parity('none');
	$port->databits(5);
	$port->stopbits(2);
	$port->handshake('none');
	$port->write_settings();

	punch_separator($port);
	punch_bin($port, $text);
	punch_separator($port);
	punch_5x5($port, $text);
	punch_separator($port);
	punch_leader($port);

	$port->close;
}

sub write2 {
	my ($port, $s) = @_;
	my $c = $port->write($s);
	if ($c != length($s)) {
		print STDERR "MISCOUNT: ".length($s)." != ".$c;
		sleep 10;
		#die "PPP";
	}
}

sub punch_leader {
	my $port = shift;
	write2($port, "\x00" x 15);
}

sub punch_separator {
	my $port = shift;
	write2($port, "\x00" x 5);
	write2($port, chr(0xFF) x 5);
	write2($port, "\x00" x 5);
}

sub punch_bin {
	my ($port, $text) = @_;
	my ($flip, $p) = (undef, undef);
	my $cur_code = \%CCH::PunchExhibit::Fonts::ita2_ustty_letters;
	my $alt_code = \%CCH::PunchExhibit::Fonts::ita2_ustty_figures;
	for my $c (split //, $text) {
		($flip, $p, $cur_code, $alt_code) = lookup_code_char($c, $cur_code, $alt_code);
		if (defined $flip) {
			write2($port, chr($flip));
		}
		write2($port, chr($p));
	}
}

sub punch_5x5 {
	my ($port, $text) = @_;

	my $sideways_5x5 = \%CCH::PunchExhibit::Fonts::sideways_5x5;
	for my $c (split //, reverse $text) {
		my $f = $sideways_5x5{$c} // $sideways_5x5{'X'};
		for my $b (0 .. 4) {
			my $byte = (
				(($f->[0] >> $b) & 1) << 0 |
				(($f->[1] >> $b) & 1) << 1 |
				(($f->[2] >> $b) & 1) << 2 |
				(($f->[3] >> $b) & 1) << 3 |
				(($f->[4] >> $b) & 1) << 4
			);
			write2($port, chr($byte));
		}
		write2($port, chr(0));
	}
}

sub update_credits {
	my $new_credits = shift;
	$credits = $new_credits;
	$kbprompt->text($new_credits < 0 ?
		' FREE PLAY ' : "CREDITS: $credits ");
	if ($credits == 0) {
		$punch_win->hide();
		$coin_win->show();
		$coin_win->focus();
	} else {
		$punch_win->show();
		$punch_win->focus();
		$coin_win->hide();
	}
}

