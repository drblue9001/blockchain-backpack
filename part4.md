Interlude: Current Events and The Tradeoffs Being Made
------------------------------------------------------

In part 1, I talked about how everyone should be at least as well off under a new proposed system as they would be under the old one. I assert that Valve would be better off under this system than they are now, but we need to be clear about what tradeoffs are involved here. Valve would be trading the ability to make arbitrary changes to the item database for increased security. This is a beneficial trade off.

[[ consider cutting next paragraph ]]
Valve does not have a good track record regarding security. Off the top of my head: they had the gem duping disaster in December which required a partial market rollback, they've had several other item duping problems (which makes me wonder about how atomic transactions are in their item database), they've had multiple remote code execution bugs, and there have been multiple problems with their user authentication system, including the recent Steam Guard bypass.

Let's talk about current events.

As I'm writing this, the security problem of the week appears to be [some sort of remote code execution attack][cssrc] against an older version of Counterstrike. Client isn't hardened. Server sends exploit to client. Machine pwned. Attacker now has control of user's computer. Steals anything of value that the user has. (And no, 2-factor authentication won't help here because the attacker now has control over the user's machine.) Classic attack. Happens way too often in the Valve ecosystem.

[cssrc]: https://www.reddit.com/r/GlobalOffensive/comments/3jpyhh/do_not_join_unkown_cs_source_servers_via_ip/

These attacks happen because having access to a user's computer is all you need to steal their items. Installing a remote control trojan gives you access to a user's logged in Steam interface. Since most users stay logged in to their webmail, the trade confirmation emails will only stop purely automated attacks.

Contrast this with the system I'm proposing, using dedicated [Trezor][trezor]-like hardware for signing digital messages. 
The attacker causes the steam client to generate the command to perform the trade, which is then displayed on the screen of the signing hardware. To actually digitally sign the command to perform the trade, the user has to actually press a button on the signing hardware, where the trade would also be displayed on the signing hardware's screen. This makes large classes of current attacks impossible, which lowers Valve's support costs and stops the inflation caused by Steam Support duped items.

[trezor]: https://www.bitcointrezor.com/

From a security standpoint, _something_ like the system I'm outlining is needed to stop the rampant hacking, but this system has costs to everyone, and it is important to consider the tradeoffs being made here.

From the user standpoint, there's a loss of convenience. While the trade conformation emails Valve currently sends aren't exactly convenient, it does mean you can trade from anywhere you have a browser. With the system I'm proposing, you'd have to have a dedicated hardware dongle to sign transactions.

Likewise, the user is now on the hook for paying transaction fees to the Ethereum network. I personally am fine with paying a couple of cents per transaction, especially to protect my hundreds of dollars of Unusuals, but this does mean that it will never make economic sense for the majority of free item drops, which are worth a penny, if that.

Likewise, there's the cost of hardware. I assume that Valve could manufacture hardware much cheaper than any of the current Bitcoin hardware wallets. This would still be a cost for the users. It's one that I'd pay, and that I think many people would be willing to pay for, but it is still an up front cost.

Finally, the user is on the hook for security of their encryption key. A user could fail to back their key up or could leak it to the internet. Both are catastrophic failure modes. One possible mitigation is to set the key at the factory and ship a copy of the key engraved metal.

From Valve's point of view, there are also downsides. Given that it doesn't make economic sense for items worth under a penny to go on chain, the current centralized item system probably has to stay. Interoperability becomes a consideration and would make any actual production ready system become more complex.

Valve currently doesn't gain any revenue from the high end unusual market as their Steam Marketplace will only accept sell orders up to $400. (For reference, a Golden Frying Pan usually goes for over $2000. A Showstopper Conga goes for $800. And don't even _look_ at what Burning Team Captains go for!) Trading these large items on chain would be safer, without the chargeback risk that comes with PayPal.

However, the Steam Marketplace does transact in lower value items, and Valve takes 15%. There are already 3rd party sellers of TF2 items who settle in fiat money, and this hasn't supplanted the official Marketplace. It's unlikely that any 3rd party marketplace built that interacts with the blockchain would take a large bite out of market profits, but it's still a risk that should be listed.

Finally, Valve has a policy of retroactively modifying a player's items to be untradable if they're caught hacking, which would generally be circumvented if something like this was deployed. I suspect that in practice this wouldn't be much of a change. People using LMAOBOX Free (which Valve can detect) usually appear to be hacking with five minute old Steam accounts, which have no items and will probably last another ten to thirty minutes before being VACed. People hacking while wearing unusuals or wielding Australium weapons are highly likely to be using the subscription LMAOBOX Premium, which Valve cannot detect. I suspect that this change would not much effect on the number of premium items that leave the economy due to being VACed.
