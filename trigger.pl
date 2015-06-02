# trigger - irssi 0.8.5
# Copyright (c) 2011 Alexandre <alex@segfault.me> Beaulieu
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

use strict;
use Irssi;

our ($VERSION, %IRSSI);
# --- Settings ---
$VERSION = "1.0"; # M.m.S
%IRSSI = (
            name        => 'Trigger',
            authors     => 'Alexandre Beaulieu',
            contact     => 'alex@segfault.me',
            url         => 'https://github.com/alxbl/trigger.pl/',
            license     => 'MIT',
            description => 'Provides a bot-like trigger that allows modules to be loaded dynamically.'
         );
Irssi::settings_add_bool('trigger', 'trigger_active', 0);
Irssi::settings_add_bool('trigger', 'trigger_debug', 0);
Irssi::settings_add_str('trigger', 'trigger_trigger', '%');
Irssi::settings_add_str('trigger', 'trigger_active_channels', '');
Irssi::settings_add_str('trigger', 'trigger_module_path', 'modules/');
Irssi::settings_add_str('trigger', 'trigger_module_autoload_path', 'trigger/autoload');

Irssi::theme_register([ 'trigger_crap', '{hilight ' .
                        $IRSSI{'name'} . '}: $0']);


# The irssi environment appears to share a common %INC that does not get reloaded
# along with the script. This subroutine ensures that core modules are forcefully
# reloaded along with the script.
sub reload_require
{
    my ($module) = @_;
    delete $INC{$module} if exists $INC{$module};
    require $module;
}


reload_require('trigger/core.pm');
reload_require('trigger/access.pm');

# === Internal Callbacks ======================================================
# Called when a message is received.
sub on_trigger_msg
{
    my ($server, $msg, $nick, $addr, $target) = @_;
    return unless (Irssi::settings_get_bool('trigger_active')); # Trigger must be enabled.
    my @channels = split (/ /, Irssi::settings_get_str('trigger_active_channels'));
    return unless (grep {/$target/} @channels); # Must be in a query or active channel.
    my $trigger = Irssi::settings_get_str('trigger_trigger');
    trigger_dispatch($1, $msg, $nick, ($target eq undef) ? $nick : $target, $server, undef) if ($msg =~ s/^$trigger(\w*)\b ?//);
}
Irssi::signal_add('message public', 'on_trigger_msg');
Irssi::signal_add('message private', 'on_trigger_msg');

# === Command hooks ===========================================================
# Usage: /TRIGGER [command [arg1 [arg2 [...] ] ]
sub on_cmd_trigger
{
    my ($data, $server, $witem) = @_;
    my @args = split / /, $data;
    unless (@args)
    {
        my $msg = 'currently' . (Irssi::settings_get_bool('trigger_active') ? '' : ' not') . ' enabled';
        trace($msg, $witem);
        return;
    }
    $_ = lc shift @args;

    # Handle -out switch.
    my $target = undef;
    if ($_ eq '-out')
    {
        $target = $witem ? $witem->{name} : undef;
        $_ = lc shift @args;
    }
    my $cmd_args = (@args) ? join ' ', @args : undef;
    trigger_dispatch($_, $cmd_args, $server->{nick}, $target, $server, $witem);
}
Irssi::command_bind('trigger', 'on_cmd_trigger');

# === Command Handler =========================================================
# Dispatch a command to the proper command handler.
sub trigger_dispatch
{
    my ($cmd, $args, $nick, $target, $server, $witem) = @_;
    my $module = core::module($cmd);
    return unless $module && $cmd =~ /$core::CMD_SYNTAX/; # Don't dispatch invalid commands.
    my @command = ($module, $args, $nick, $target, $server, $witem);
    Irssi::timeout_add_once(10, "handle_command", \@command);
}

# Executes a command
sub handle_command
{
    my ($module, $args, $nick, $target, $server, $witem) =  @{$_[0]};
    eval
    {
        my $data = $module->{'run'}($args, $nick, $target, $server);
        trace("handle_command <$nick> $module->{'name'}($args) -> $target\n>> $data") if (Irssi::settings_get_bool('trigger_debug'));
        if ($target && $data)
        {
            $witem ? $server->command("MSG $target >> $module->{'name'}($args) => $data") # $target && $witem => /trigger -out
                : $server->command("MSG $target $data"); # Otherwise, luser command.
        }
        trace($data, $witem) if ($target eq undef && $data);
        return 1;
    }
    or do
    {
        my $ex = $@;
        trace("Error while running `$module->{'name'}($args)`: $ex", $witem);
        return 0;
    }
}

# === Output Helpers ==========================================================
sub trace
{
    my ($msg, $witem) = @_;
    if ($witem)
    {
        $witem->window()->printformat(MSGLEVEL_CRAP, 'trigger_crap', $msg);
    }
    else
    {
        Irssi::printformat(MSGLEVEL_CRAP, 'trigger_crap', $msg);
    }
}
