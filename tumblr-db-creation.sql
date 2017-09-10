CREATE TABLE "pic" ( `post` INTEGER, `offset` INTEGER, `url` TEXT, `thumb` TEXT, PRIMARY KEY(`post`,`offset`), FOREIGN KEY(`post`) REFERENCES `post`(`id`) );
CREATE TABLE "post" ( `id` INTEGER, `tumblr` TEXT, `type` TEXT, `slug` TEXT, `text` INTEGER, `date` INTEGER, `pic` TEXT, `new` INTEGER DEFAULT 1, `fav` INTEGER DEFAULT 0, `reblog` INTEGER DEFAULT 0, `fresh` INTEGER DEFAULT 0, PRIMARY KEY(`id`), FOREIGN KEY(`tumblr`) REFERENCES `tumblr`(`name`) );
CREATE TABLE "repostsrc" ( `tumblr` TEXT, `visited` INTEGER DEFAULT 0, `have` INTEGER DEFAULT 0, `post` INTEGER, `base` TEXT, PRIMARY KEY(`tumblr`) );
CREATE TABLE "tumblr" ( `name` TEXT, `url` TEXT, `update` INTEGER, `status` INTEGER, `statusdif` INTEGER, `solution` TEXT, PRIMARY KEY(`name`) );
