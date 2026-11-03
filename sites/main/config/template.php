<?php

use FastRaven\Components\Core\Template;

use FastRaven\Bee;

// Default template for all views. Pages render in the client's preferred language (cookie, then Accept-Language).
$template = Template::new("main.php", "Fast Raven Site", Bee::env("VERSION", "0.0.1"));
$template->setLangFile("global")
         ->setDefaultLang("en")
         ->setFavicon("favicon.png")
         ->addMeta("description", "A site powered by Fast Raven.")
         ->setBeforeFragments(["header.php"])
         ->addStyle("style.css")
         ->addScript("main.js");

return $template;
