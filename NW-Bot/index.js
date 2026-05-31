const {
    Client,
    GatewayIntentBits,
    ChannelType
} = require("discord.js");

const inquirer = require("inquirer");
const chalk = require("chalk");
const axios = require("axios");

const client = new Client({
    intents: [GatewayIntentBits.Guilds]
});

async function pause() {
    await inquirer.prompt([
        {
            type: "input",
            name: "continue",
            message: "Press ENTER to continue"
        }
    ]);
}

async function createChannels(guild) {

    const answers = await inquirer.prompt([
        {
            type: "input",
            name: "name",
            message: "Channel name:"
        },
        {
            type: "number",
            name: "amount",
            message: "Amount:"
        }
    ]);

    console.log(
        chalk.yellow("\nCreating channels...\n")
    );

    for (let i = 0; i < answers.amount; i++) {

        try {

            await guild.channels.create({
                name: `nw-${answers.name}-${i + 1}`,
                type: ChannelType.GuildText
            });

            console.log(
                chalk.green(
                    `✓ Created nw-${answers.name}-${i + 1}`
                )
            );

        } catch (err) {

            console.log(
                chalk.red(
                    `✗ Failed nw-${answers.name}-${i + 1}`
                )
            );
        }
    }

    await pause();

    return menu(guild);
}

async function createRoles(guild) {

    const answers = await inquirer.prompt([
        {
            type: "input",
            name: "name",
            message: "Role name:"
        },
        {
            type: "number",
            name: "amount",
            message: "Amount:"
        }
    ]);

    console.log(
        chalk.yellow("\nCreating roles...\n")
    );

    for (let i = 0; i < answers.amount; i++) {

        try {

            await guild.roles.create({
                name: `nw-${answers.name}-${i + 1}`
            });

            console.log(
                chalk.green(
                    `✓ Created role nw-${answers.name}-${i + 1}`
                )
            );

        } catch (err) {

            console.log(
                chalk.red(
                    `✗ Failed role nw-${answers.name}-${i + 1}`
                )
            );
        }
    }

    await pause();

    return menu(guild);
}

async function cleanupToolItems(guild) {

    console.log(
        chalk.yellow("\nCleaning up tool items...\n")
    );

    // REFRESH CACHE
    await guild.channels.fetch();
    await guild.roles.fetch();

    // DELETE TEXT + VOICE CHANNELS FIRST
    for (const channel of guild.channels.cache.values()) {

        if (
            channel.name.startsWith("nw-") &&
            channel.type !== ChannelType.GuildCategory
        ) {

            try {

                await channel.delete();

                console.log(
                    chalk.green(
                        `✓ Deleted channel ${channel.name}`
                    )
                );

            } catch (err) {

                console.log(
                    chalk.red(
                        `✗ Failed channel ${channel.name}`
                    )
                );
            }
        }
    }

    // DELETE CATEGORIES AFTER CHANNELS
    for (const channel of guild.channels.cache.values()) {

        if (
            channel.name.startsWith("nw-") &&
            channel.type === ChannelType.GuildCategory
        ) {

            try {

                await channel.delete();

                console.log(
                    chalk.green(
                        `✓ Deleted category ${channel.name}`
                    )
                );

            } catch (err) {

                console.log(
                    chalk.red(
                        `✗ Failed category ${channel.name}`
                    )
                );
            }
        }
    }

    // DELETE ROLES
    for (const role of guild.roles.cache.values()) {

        if (
            role.name.startsWith("nw-") &&
            role.name !== "@everyone" &&
            !role.managed
        ) {

            try {

                await role.delete();

                console.log(
                    chalk.green(
                        `✓ Deleted role ${role.name}`
                    )
                );

            } catch (err) {

                console.log(
                    chalk.red(
                        `✗ Failed role ${role.name}`
                    )
                );
            }
        }
    }

    console.log(
        chalk.cyan("\n✓ Cleanup complete.\n")
    );

    await pause();

    return menu(guild);
}

async function massRenameChannels(guild) {

    const answers = await inquirer.prompt([
        {
            type: "input",
            name: "name",
            message: "New channel name:"
        }
    ]);

    console.log(
        chalk.yellow("\nRenaming channels...\n")
    );

    let count = 1;

    for (const channel of guild.channels.cache.values()) {

        try {

            await channel.setName(
                `${answers.name}-${count}`
            );

            console.log(
                chalk.green(
                    `✓ Renamed to ${answers.name}-${count}`
                )
            );

            count++;

        } catch {

            console.log(
                chalk.red(
                    `✗ Failed ${channel.name}`
                )
            );
        }
    }

    await pause();

    return menu(guild);
}

async function massRenameRoles(guild) {

    const answers = await inquirer.prompt([
        {
            type: "input",
            name: "name",
            message: "New role name:"
        }
    ]);

    console.log(
        chalk.yellow("\nRenaming roles...\n")
    );

    let count = 1;

    for (const role of guild.roles.cache.values()) {

        if (role.name === "@everyone") continue;

        try {

            await role.setName(
                `${answers.name}-${count}`
            );

            console.log(
                chalk.green(
                    `✓ Renamed role to ${answers.name}-${count}`
                )
            );

            count++;

        } catch {

            console.log(
                chalk.red(
                    `✗ Failed role ${role.name}`
                )
            );
        }
    }

    await pause();

    return menu(guild);
}

async function importTemplate(guild) {

    const { link } = await inquirer.prompt([
        {
            type: "input",
            name: "link",
            message: "Discord template link:"
        }
    ]);

    const code = link.split("/").pop();

    try {

        console.log(
            chalk.yellow("\nFetching template...\n")
        );

        const res = await axios.get(
            `https://discord.com/api/v10/guilds/templates/${code}`
        );

        const template =
            res.data.serialized_source_guild;

        // CREATE ROLES
        console.log(
            chalk.cyan("Creating roles...\n")
        );

        for (const role of template.roles) {

            if (role.name === "@everyone")
                continue;

            try {

                await guild.roles.create({
                    name: role.name,
                    color: role.color || undefined,
                    hoist: role.hoist || false,
                    mentionable:
                        role.mentionable || false
                });

                console.log(
                    chalk.green(
                        `✓ Role created: ${role.name}`
                    )
                );

            } catch {

                console.log(
                    chalk.red(
                        `✗ Failed role: ${role.name}`
                    )
                );
            }
        }

        // CATEGORY MAP
        const categoryMap = new Map();

        console.log(
            chalk.cyan(
                "\nCreating categories...\n"
            )
        );

        // CREATE CATEGORIES FIRST
        for (const channel of template.channels) {

            if (channel.type === 4) {

                try {

                    const createdCategory =
                        await guild.channels.create({
                            name: channel.name,
                            type:
                                ChannelType.GuildCategory
                        });

                    categoryMap.set(
                        channel.id,
                        createdCategory.id
                    );

                    console.log(
                        chalk.green(
                            `✓ Category created: ${channel.name}`
                        )
                    );

                } catch {

                    console.log(
                        chalk.red(
                            `✗ Failed category: ${channel.name}`
                        )
                    );
                }
            }
        }

        console.log(
            chalk.cyan(
                "\nCreating channels...\n"
            )
        );

        // CREATE CHANNELS
        for (const channel of template.channels) {

            if (channel.type === 4)
                continue;

            try {

                let type =
                    ChannelType.GuildText;

                if (channel.type === 2) {
                    type =
                        ChannelType.GuildVoice;
                }

                const parentId =
                    channel.parent_id
                        ? categoryMap.get(
                              channel.parent_id
                          )
                        : null;

                await guild.channels.create({
                    name: channel.name,
                    type,
                    parent:
                        parentId || undefined
                });

                console.log(
                    chalk.green(
                        `✓ Channel created: ${channel.name}`
                    )
                );

            } catch {

                console.log(
                    chalk.red(
                        `✗ Failed channel: ${channel.name}`
                    )
                );
            }
        }

        console.log(
            chalk.green(
                "\n✓ Template imported successfully\n"
            )
        );

    } catch (err) {

        console.log(
            chalk.red(
                "\n✗ Failed to import template\n"
            )
        );
    }

    await pause();

    return menu(guild);
}

async function menu(guild) {

    console.clear();

    console.log(
        chalk.cyan(`
╔════════════════════════════╗
║      Discord Tool v1      ║
╚════════════════════════════╝
`)
    );

    console.log(
        chalk.green(
            `Logged into: ${guild.name}\n`
        )
    );

    const { action } =
        await inquirer.prompt([
            {
                type: "list",
                name: "action",
                message: "Select option",
                choices: [
                    "Create Channels",
                    "Create Roles",
                    "Import Template",
                    "Cleanup Tool Items",
                    "Mass Rename Channels",
                    "Mass Rename Roles",
                    "Exit"
                ]
            }
        ]);

    if (action === "Create Channels") {
        return createChannels(guild);
    }

    if (action === "Create Roles") {
        return createRoles(guild);
    }

    if (action === "Import Template") {
        return importTemplate(guild);
    }

    if (action === "Cleanup Tool Items") {
        return cleanupToolItems(guild);
    }

    if (action === "Mass Rename Channels") {
        return massRenameChannels(guild);
    }

    if (action === "Mass Rename Roles") {
        return massRenameRoles(guild);
    }

    process.exit();
}

client.once("clientReady", async () => {

    console.clear();

    console.log(
        chalk.green(`
Logged in as ${client.user.tag}
`)
    );

    const guildChoices =
        client.guilds.cache.map(guild => ({
            name: guild.name,
            value: guild.id
        }));

    const { guildId } =
        await inquirer.prompt([
            {
                type: "list",
                name: "guildId",
                message: "Select server",
                choices: guildChoices
            }
        ]);

    const guild =
        client.guilds.cache.get(guildId);

    menu(guild);
});

(async () => {

    console.clear();

    console.log(
        chalk.cyan(`
╔════════════════════════════╗
║      Discord Tool v1      ║
╚════════════════════════════╝
`)
    );

    const { token } =
        await inquirer.prompt([
            {
                type: "password",
                name: "token",
                message: "Enter bot token:"
            }
        ]);

    client.login(token);
})();