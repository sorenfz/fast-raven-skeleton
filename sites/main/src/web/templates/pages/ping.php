<h2 data-lang="FR_PING_EXAMPLE"><?= $template->lang("FR_PING_EXAMPLE"); ?></h2>
<h4>PING -> <span id="pong-answer"></span></h4>
<p><?= $template->getData("test"); ?></p>
<button onclick="Lib.changeLanguage(Lib.CURRENT_LANGUAGE === 'en' ? 'es' : 'en')">Switch language</button>

<script nonce="<?= $template->getNonce(); ?>">
    // Avoid using inline-scripts, this is just an example.
    // If needed, always use the nonce provided by the template.
    
    const res = Lib.request("/api/pong", "POST", {"question": "What time is it?"}).then(function(res){
        $("#pong-answer").text(res.data.answer);
    }).catch(function(err){
        $("#pong-answer").text(err.message);
    });
</script>
