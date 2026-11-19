# Ketik Saji | Coordinator’s original playtest notes

The coordinator supplied the two messages below. The message text is reproduced as written, including spelling, examples, and order. The companion [implementation brief](KETIK_SAJI_PLAYTEST_BUGFIX_BRIEF.md) derives its requirements from these messages. The original message also included four screenshots of the game UI.

## Original message

```text
i have done some test and found these to be my complaints, this is quite an unstructured list though so i need your help in making it clearer. try your best to understand what i mean. the end goal here is to send this report to the dev. but we need to make this clear first, dont need the handoff yet
here it is:

clicking on storage containers should not automatically open the purchase ingredient menu. player should decide when they want to open purchase ingredients menu by clicking the storage container and typing "beli"
currently when in serving stage, when clicking storage container player immediately sees the purchase ingredient view, they should instead first just see the normal take item view. also currently the take item view lists all available ingredients to take (like ayam, telur, sapi, telur, beras, etc) even though those ingredients are not stored in the storage container. the tooltip only should show the available ingredients. this logic of only showing the available commands should apply to everything
currently in the planning view, when clicking a non interactible utility, the tooltip spawns at the top. when clicking that tooltip, it seems like the game thinks the player want to teleport into the tile behind the tooltip. this is confusing, so make clicking the tooltip actually be the same as clicking the utility instead, so that the game does not complain that the floor cant be teleported into.
currently after washing rice, and cooking it, the rice in the rice cooker only lasts for 1 serving. rice should last in the rice cooker for 5 servings before the player needs to wash another batch.
currently when holding a plate, the player cannot put other items on that plate. the player should be able to hold a plate and take out rice or other ingredients and put those on the plate. same goes both ways, the player should be able to hold a plateable ingredient, and then click on the plate rack or a plate to plate it.
currently in the left UI strip im not seeing the goal in numerical value
also, clicking esc should make the player not interact, but stay in the same place
currently the customers sit on the table instead of the chair, but the dev has not placed any chair near a table, so i will instruct the dev to do so and the agent should fix the logic.
currently when the game is running, user cannot pause. user should be able to pause the game and exit if they press esc or press a button on the big ui strip.
also currently the big UI strip is too thin, some info there arent visible.
menu too verbose, heres my complaints:
the belanja bahan menu has too many unecessary info. since the left UI strip is still visible, it doesnt need to show the money the player currently has. also it doesnt need to show total capacity as players can literally just add them together. in the planning stage, dont need to show that "tiba langsung". the storage indicators dont need to show the name of slots, instead of S1 S2 etc it doesnt need to show that they are, having them already be separated is enough. what even is when theres no delayed delivery, it doesnt need to show it. on the list itself, the "stok" counter doesnt need to exists since its basically the same info as in the slot, again the players can do simple math.
the belanja peralatan screen again has too many info. first it doesnt need to show how much money the player has since it always shows that on the left UI strip. also why is there options to choose the slots? this would make it confusing. there player should know where the utility is going to be placed by clicking the location in world, they dont need to have the option to change that in menu. i agree with that theres 2 types of utility placer, a table and a utility. so this means the game should already know what utility can be purchased where. removing the need for a line of text.
the list themselves have too much info for each entry. for example (with labels for each line):
a. kompor [Alat masak] - Rp60000
b. manfaat: +1 kompor untuk menggoreng paralel
c. beban (complexity debt): listrik Rr0/hari, pakai 1 slot dapur permanen
d. Alat tidak cocok dengan slot ini. (slot kosong kompatibel: 2)
line A has redundant info, it should only show Kompor: Rpxx
line b should be a description like "untuk memasak"
line c and d does not need to exists.
if the utility has an electricity price, it should show that in the description "Buat nyimpen bahan sampai beberapa hari (listrik: 4k/hari)"
also, the sprite for the utilities should be shown to the left of these texts, make sure the size are correct.
also the bottom most tooltip where "utility -> slot" should instead be replaced by harga:


edit menu screen should me almost the same, but the emdash be a :
the menu themselves will actually have a final sprite design thats currently in process. so the menu should use those sprite designs, btw the [aktif] should be instead changed to an actual checkmark so that its smaller
make the menu thinner, and add another panel directly next to the right of it without any space for the ingredient list. it should show from top to bottom:
dish name
ingredient 1
ingredient 2 (potong)
etc

thats it, everything on the ingredient should be assumed to need to be cooked first, but dont need to put that verbosely on the menu, the player already knows. only put indicator when the item doesnt need to be cooked and instead be prepared differently.


the game is currently way too verbose on when the player does something incorrect. UI should convey this rather than texts. for example:
typing something incorrectly would display "huruf tidak cocok" and shakes the tooltip, it should need to tell me what happens, as i can already understand that the shaking and a letter not registering as an error.




btw i want to make some change to how the money is displayed, since we dont need a lot of percision at all, maybe 1 number after the decimal at most. change every money value counter to use the format Rpxxk instead, example Rp 4000 should be Rp 4k
and Rp 4500 should be Rp 4.5k
remember to put a space between Rp and the number so its more legible
```

## Follow-up message

```text
more stuff: after the customer has eaten, the dirty plate should just be a plate icon with a tooltip meja kotor
for the belanja peralatan, the name and price is one line, but the description should be in its own line below, name and price is bold, desc is normal
```
