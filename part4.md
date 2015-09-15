Interlude: Current Events and Why these Things have Value
---------------------------------------------------------

In part 1, I talked about how everyone should be at least as well off under a new proposed system as they would be under the old one. I assert that Valve would be better off under this system than they are now, but we need to be clear about what tradeoffs are involved here. Valve would be trading the ability to make arbitrary changes to the item database for increased security.

Valve does not have a good track record regarding security. Off the top of my head: they had the gem duping disaster in December which required a partial market rollback, they've had several item duping problems (which makes me wonder about how atomic operations are in their item database), they've had multiple remote code execution bugs, and there have been multiple problems with their user authentication system, including the recent Steam Guard bypass.

Let's talk about current events.

As I'm writing this, the security problem of the week appears to be [some sort of remote code execution attack][cssrc] against an older version of Counterstrike. Client isn't hardened. Server sends exploit to client. Machine pwned. Attacker now has control of user's computer. Steals anything of value that the user has. (And no, 2-factor authentication won't help here because the attacker now has control over the user's machine.) Classic attack. Happens way too often in the Valve ecosystem.

[cssrc]: https://www.reddit.com/r/GlobalOffensive/comments/3jpyhh/do_not_join_unkown_cs_source_servers_via_ip/

These attacks happen because having access to a user's computer is all you need to steal their items. Installing a remote control trojan gives you access to a user's logged in Steam interface. Since most users stay logged in to their webmail, the trade confirmation emails will only stop purely automated attacks.

Contrast this with the system I'm proposing, using dedicated [Trezor][trezor]-like hardware for signing digital messages. 
The attacker causes the steam client to generate the command to perform the trade, which is then displayed on the screen of the signing hardware. To actually digitally sign the command to perform the trade, the user has to actually press a button on the signing hardware, where the trade would also be displayed on the signing hardware's screen. This makes large classes of current attacks impossible.

[trezor]: https://www.bitcointrezor.com/

The flip side is a loss of control. The system as outlined here puts control of items completely in the hands of the user. As outlined in part 2, to execute any code to modify the item, the owner unlock the item for that contract. The implication is that not only could a 3rd party not take or modify a user's items, _Valve_ couldn't take or modify a users items.

There are upsides here. Steam Support's workload should go down significantly, since claims of item theft by users who are using this system are not credible. Likewise, Steam Support could push people to opt-in to this system in return for restoring their stolen items.

## TODO: Write about how uncrating is a proof of burn operation.
