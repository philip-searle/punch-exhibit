#!/usr/bin/perl

use Modern::Perl;
use Curses::UI;
use Curses;

my $UC_SPROCKET = "\N{U+00B7}";
my $UC_SPACE = "\N{U+0020}";
my $UC_HOLE = "\N{U+25CF}";

my %ita2_ustty_letters = (
	\0	=> 0b00000,
	E	=> 0b00001,
	\n	=> 0b00010,
	A	=> 0b00011,
	' '	=> 0b00100,
	S	=> 0b00101,
	I	=> 0b00110,
	U	=> 0b00111,
	\r	=> 0b01000,
	D	=> 0b01001,
	R	=> 0b01010,
	J	=> 0b01011,
	N	=> 0b01100,
	F	=> 0b01101,
	C	=> 0b01110,
	K	=> 0b01111,
	T	=> 0b10000,
	Z	=> 0b10001,
	L	=> 0b10010,
	W	=> 0b10011,
	H	=> 0b10100,
	Y	=> 0b10101,
	P	=> 0b10110,
	Q	=> 0b10111,
	O	=> 0b11000,
	B	=> 0b11001,
	G	=> 0b11010,
	figs	=> 0b11011,
	M	=> 0b11100,
	X	=> 0b11101,
	V	=> 0b11110,
	ltrs	=> 0b11111,
	FLIP	=> 0b11011	# to figs
);
my %ita2_ustty_figures = (
	\0	=> 0b00000,
	3	=> 0b00001,
	\n	=> 0b00010,
	'-'	=> 0b00011,
	' '	=> 0b00100,
	\007	=> 0b00101,
	8	=> 0b00110,
	7	=> 0b00111,
	\r	=> 0b01000,
	$	=> 0b01001,
	4	=> 0b01010,
	"'"	=> 0b01011,
	,	=> 0b01100,
	'!'	=> 0b01101,
	':'	=> 0b01110,
	'('	=> 0b01111,
	5	=> 0b10000,
	'"'	=> 0b10001,
	')'	=> 0b10010,
	2	=> 0b10011,
	'#'	=> 0b10100,
	6	=> 0b10101,
	0	=> 0b10110,
	1	=> 0b10111,
	9	=> 0b11000,
	'?'	=> 0b11001,
	'&'	=> 0b11010,
	figs	=> 0b11011,
	'.'	=> 0b11100,
	'/'	=> 0b11101,
	';'	=> 0b11110,
	ltrs	=> 0b11111,
	FLIP	=> 0b11111	# to ltrs
);	

my $user_prompt = <<PROMPT;


	Enter your name below and press ENTER.

	Our paper tape machine will punch it out as machine-readable
	ITA2/US-TTY Baudot-Murray code, as well as human-readable
	sideways text.

	You get up to 40 characters, so make good use of them!
PROMPT

my $cui = Curses::UI->new(
	-clear_on_exit => 1,
	-color_support => 1,
	-debug => 0
);

my $status_window = $cui->add(
	'status_window', 'Window',
	-x => 0, -y => 23,
	-width => 80, -height => 1
);

my $kbstatus = $status_window->add(
	'kbstatus', 'Label',
	-x => 0, -y => 0,
	-width => 60, -height => 1,
	-text => " EXHIBIT-4601/PI3\tCREDIT:0\tONLINE",
	-dim => 1
);

my $kbprompt = $status_window->add(
	'kbprompt', 'Label',
	-x => 60, -y => 0,
	-width => 20, -height => 1,
	-text => "CTRL-C TO QUIT ",
	-dim => 1,
	-textalignment => 'right'
);

my $win = $cui->add(
	'main_window', 'Window',
	-border => 0,
	-width => 80, -height => 16
);

my $textbg = $win->add(
	'textbg', 'Label',
	-x => 0, -y => 0,
	-width => 78, -height => 24,
	-dim => 0, -paddingspaces => 1,
	-text => $user_prompt,
);

my $preview_win = $cui->add(
	'preview_window', 'Window',
	-title => "Punch Tape Preview",
	-border => 1,
	-x => 0, -y => 16,
	-width => 80, -height => 7
);

my $tape_preview = $preview_win->add(
	'tape_preview', 'Label',
	-x => 0, -y => 0,
	-width => 78, -height => 5,
	-text => preview_tape(""), -textalignment => 'right'
);

sub handle_name {
	my $widget = shift;
	my $name = $widget->text();
	$tape_preview->text(preview_tape($name));
	$preview_win->draw();
}

my $namefield = $win->add(
	'namefield', 'TextEntry',
	-x => 19, -y => 12,
	-width => 42, -height => 1,
	-toupper => 1,
	-onchange => \&handle_name,
	-sbborder => 0, -showlines => 1,
	-maxlength => 40
);

my $punching_win = $cui->add(
	'punching_win', 'Window',
	-title => "Punching your text ...",
	-border => 1,
	-x => 0, -y => 0,
	-width => 80, -height => 23
);

$cui->set_binding(sub {$cui->mainloopExit;}, "\cC");
$cui->set_binding(\&do_punch, KEY_ENTER);
$punching_win->hide();
$namefield->focus();
$cui->mainloop;

sub lookup_code_char {
	my ($c, $cur_code, $alt_code) = @_;
	my $code = $cur_code->{$c};
	if (defined $code) {
		return (undef, $code, $cur_code, $alt_code);
	}
	$code = $alt_code->{$c};
	if (defined $code) {
		return ($cur_code->{FLIP}, $code, $alt_code, $cur_code);
	}
	return (undef, $cur_code->{' '}, $cur_code, $alt_code);
}

sub preview_tape {
	my $text = shift;
	my ($preview, $flip, $p) = ('', undef, undef);
	for my $b (0 .. 4) {
		my $cur_code = \%ita2_ustty_letters;
		my $alt_code = \%ita2_ustty_figures;
		for my $c (split //, $text) {
			($flip, $p, $cur_code, $alt_code) = lookup_code_char($c, $cur_code, $alt_code);
			if (defined $flip) {
				$preview .= $flip & (1<<$b) ? $UC_HOLE : $UC_SPACE;
			}
			$preview .= $p & (1<<$b) ? $UC_HOLE : $UC_SPACE;
		}
		$preview .= "\n";
		if ($b == 1) {
			$preview .= $UC_SPROCKET x 78 . "\n";
		}
	}
	return $preview;
}

sub do_punch {
	$win->hide();
	$preview_win->hide();
	$punching_win->show();
	$cui->draw();
	sleep(10);
	$namefield->text('');
	handle_name($namefield);
	$win->show();
	$preview_win->show();
	$punching_win->hide();
	$cui->draw();
}

