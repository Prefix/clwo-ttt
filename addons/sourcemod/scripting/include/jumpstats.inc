#if defined _jumpstats_included_
  #endinput
#endif
#define _jumpstats_included_

/**
 * JumpTypes.
 */
enum JumpType
{
    Jump_None,
    Jump_LJ,
    Jump_BHJ,
    Jump_MBHJ,
    Jump_LadJ,
    Jump_WHJ,
    Jump_LDHJ,
    Jump_LBHJ,

    Jump_End // Anchor for iteration
};

//Jump consts
stock const char g_saJumpTypes[][] =
{
    "None",
    "LJ",
    "BHJ",
    "MBHJ",
    "LadJ",
    "WHJ",
    "LDHJ",
    "LBHJ"
};
stock const char g_saPrettyJumpTypes[][] =
{
    "None",
    "Long Jump",
    "BunnyHop Jump",
    "Multi BunnyHop Jump",
    "Ladder Jump",
    "WeirdHop Jump",
    "Ladder DropHop Jump",
    "Ladder BunnyHop Jump"
};

/**
 * @brief Interrupts a player's current jump stats recording.
 *
 * @param client    The target player.
 * @return          True if the jump was successfully interrupted, false otherwise.
 */
native bool JumpStats_InterruptJump(int client);

/**
 * Off tracking of client.
 *
 * @param client    Client index.
 * @noreturn
 */
native void JumpStats_ClientUntrack(int client);

/**
 * On tracking of client.
 *
 * @param client    Client index.
 * @noreturn
 */
native void JumpStats_ClientTrack(int client);

/**
 * Returns if a certain player has tracked.
 *
 * @param client    Client index.
 * @return          True if player has tracked, false otherwise.
 */
native bool JumpStats_ClientIsTracked(int client);

/**
 * Called when player do a jump.
 */
forward void JumpStats_OnJump(int client, JumpType type, float distance);

public SharedPlugin __pl_jumpstats =
{
    name = "jumpstats",
    file = "jumpstats.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_jumpstats_SetNTVOptional()
{
    MarkNativeAsOptional("JumpStats_InterruptJump");
    MarkNativeAsOptional("JumpStats_ClientUntrack");
    MarkNativeAsOptional("JumpStats_ClientTrack");
    MarkNativeAsOptional("JumpStats_ClientIsTracked");
}
#endif