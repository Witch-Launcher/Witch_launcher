package com.mojang.text2speech;

public interface Narrator {
    Narrator EMPTY = new NarratorDummy();

    void say(final String msg, final boolean interrupt);

    void clear();

    boolean active();

    void destroy();

    static Narrator getNarrator() {
        return EMPTY;
    }

    static void setJNAPath(String sep) {
        System.setProperty("jna.library.path", System.getProperty("jna.library.path") + sep + "./src/natives/resources/");
        System.setProperty("jna.library.path", System.getProperty("jna.library.path") + sep + System.getProperty("java.library.path"));
    }

    class InitializeException extends RuntimeException {
        public InitializeException(final String message) {
            super(message);
        }

        public InitializeException(final String message, final Throwable cause) {
            super(message, cause);
        }
    }
}
