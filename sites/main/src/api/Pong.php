<?php

use FastRaven\Components\Http\Request;
use FastRaven\Components\Http\Response;
use FastRaven\Types\SanitizeType;

use Site\PongRepository;

return function(Request $request): Response {
    $question = $request->post("question", SanitizeType::SANITIZED);

    if($question === null) return Response::new(false, 400, "Missing question.");

    $answer = PongRepository::answer($question);
    if($answer === null) return Response::new(false, 400, "Invalid question.");

    return Response::new(true, 200, "Valid question.", ["answer" => $answer]);
};
