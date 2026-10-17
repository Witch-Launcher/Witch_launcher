/*
 * Copyright LWJGL. All rights reserved.
 * License terms: https://www.lwjgl.org/license
 * MACHINE GENERATED FILE, DO NOT EDIT
 */
package org.lwjgl.system;

import org.jspecify.annotations.*;
import org.lwjgl.system.ffm.*;
import java.lang.foreign.*;
import java.lang.invoke.*;

import static org.lwjgl.system.ffm.FFM.*;

public final class JNI {

    @FFMFunctionAddress
    private interface JNIBindings {
        short invokePC(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        double invokeD(MemorySegment __functionAddress);
        double invokeD(MemorySegment __functionAddress, int param0);
        double invokePD(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        double invokePD(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        float invokeF(MemorySegment __functionAddress, int param0);
        float invokePF(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        float invokePF(MemorySegment __functionAddress, float param0, @FFMNullable @FFMPointer long param1);
        float invokePF(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        float invokePF(MemorySegment __functionAddress, float param0, float param1, @FFMNullable @FFMPointer long param2);
        float invokePF(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        int invokeI(MemorySegment __functionAddress);
        int invokeI(MemorySegment __functionAddress, int param0);
        int invokeI(MemorySegment __functionAddress, int param0, int param1);
        int invokePI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        int invokePI(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1);
        int invokePI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        int invokePI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        int invokePI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, boolean param2);
        int invokePI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3);
        int invokePI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5, int param6);
        int invokePNI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1);
        int invokePNI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2);
        int invokePPI(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, boolean param2);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, boolean param1, @FFMNullable @FFMPointer long param2);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, boolean param3);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, boolean param2, @FFMNullable @FFMPointer long param3);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, int param3);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, boolean param2, boolean param3);
        int invokePPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4);
        int invokePCPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, short param1, @FFMNullable @FFMPointer long param2);
        int invokePNNI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2);
        int invokePNPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2);
        int invokePPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        int invokePNPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, @FFMNullable @FFMPointer long param3);
        int invokePPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        int invokePPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3);
        int invokePPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3);
        int invokePNNI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, int param3, int param4);
        int invokePPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        int invokePPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4);
        int invokePPNNI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2, long param3);
        int invokePPNPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2, @FFMNullable @FFMPointer long param3);
        int invokePPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        int invokePNNPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, long param3, @FFMNullable @FFMPointer long param4);
        int invokePPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        int invokePNNPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        int invokePPNNPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2, long param3, @FFMNullable @FFMPointer long param4);
        int invokePPPPNI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, long param4);
        int invokePPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        int invokePPNPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        int invokePPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        int invokePNPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        int invokePPPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        int invokePPPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        int invokePNNPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, int param3, int param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
        int invokePPPPPPI(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
        int invokePPPPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        int invokePPPPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7, @FFMNullable @FFMPointer long param8);
        long invokeJ(MemorySegment __functionAddress);
        long invokePJ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        long invokePJ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        long invokePJ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        long invokeNN(MemorySegment __functionAddress, long param0);
        long invokePN(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        long invokePN(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        long invokeNNN(MemorySegment __functionAddress, long param0, long param1);
        long invokePPN(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1);
        long invokeNNNN(MemorySegment __functionAddress, long param0, long param1, long param2);
        long invokePNPN(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2);
        long invokePNPN(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2, int param3);
        long invokePPNN(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3, long param4);
        long invokePNPNN(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2, long param3);
        long invokePNPNPN(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, @FFMNullable @FFMPointer long param9, long param10, @FFMNullable @FFMPointer long param11);
        @FFMPointer long invokeP(MemorySegment __functionAddress);
        @FFMPointer long invokeP(MemorySegment __functionAddress, int param0);
        @FFMPointer long invokeP(MemorySegment __functionAddress, int param0, int param1);
        @FFMPointer long invokePP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        @FFMPointer long invokePP(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1);
        @FFMPointer long invokePP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        @FFMPointer long invokePP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        @FFMPointer long invokePP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3);
        @FFMPointer long invokePP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5);
        @FFMPointer long invokePNP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1);
        @FFMPointer long invokePPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1);
        @FFMPointer long invokePCP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, short param1, boolean param2);
        @FFMPointer long invokePPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2);
        @FFMPointer long invokePPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2);
        @FFMPointer long invokePPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3);
        @FFMPointer long invokePPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, boolean param2, boolean param3);
        @FFMPointer long invokePPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, boolean param1, boolean param2, @FFMNullable @FFMPointer long param3);
        @FFMPointer long invokePPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        @FFMPointer long invokePPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        @FFMPointer long invokePPPP(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        @FFMPointer long invokeJPPP(MemorySegment __functionAddress, int param0, int param1, int param2, long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        @FFMPointer long invokePNNPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, @FFMNullable @FFMPointer long param3);
        @FFMPointer long invokePPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        @FFMPointer long invokePPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        @FFMPointer long invokePJPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        @FFMPointer long invokePNNNPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3, @FFMNullable @FFMPointer long param4);
        @FFMPointer long invokePPPPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        void invokeV(MemorySegment __functionAddress);
        void invokeV(MemorySegment __functionAddress, double param0);
        void invokeV(MemorySegment __functionAddress, float param0);
        void invokeV(MemorySegment __functionAddress, int param0);
        void invokeV(MemorySegment __functionAddress, int param0, float param1);
        void invokeV(MemorySegment __functionAddress, int param0, int param1);
        void invokeV(MemorySegment __functionAddress, int param0, int param1, double param2);
        void invokeV(MemorySegment __functionAddress, int param0, int param1, float param2);
        void invokeV(MemorySegment __functionAddress, int param0, int param1, int param2);
        void invokeV(MemorySegment __functionAddress, int param0, float param1, float param2, float param3);
        void invokeV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3);
        void invokeV(MemorySegment __functionAddress, int param0, int param1, double param2, double param3, double param4);
        void invokeV(MemorySegment __functionAddress, int param0, int param1, float param2, float param3, float param4);
        void invokeV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        void invokeJV(MemorySegment __functionAddress, int param0, long param1);
        void invokePV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, float param1);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, boolean param1);
        void invokeJV(MemorySegment __functionAddress, int param0, int param1, long param2);
        void invokePV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2);
        void invokePV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, boolean param2);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, double param1, double param2);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, float param1, float param2);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, double param2);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, float param2);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        void invokePV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, double param3);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, float param3);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3);
        void invokePV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, float param2, float param3, float param4);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4);
        void invokePV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void invokePV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4, boolean param5);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, double param3, double param4, double param5);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, float param3, float param4, float param5);
        void invokePV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5);
        void invokePV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6);
        void invokePJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1);
        void invokePNV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1);
        void invokePJV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, long param2);
        void invokePJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, boolean param2);
        void invokePBV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, byte param3);
        void invokePCV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, short param3);
        void invokePJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, long param3);
        void invokePPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, boolean param3);
        void invokePSV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, short param3);
        void invokePUV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, byte param3);
        void invokePPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4);
        void invokePPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3, int param4, int param5);
        void invokePPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5, boolean param6);
        void invokePPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, int param3, int param4, int param5, int param6);
        void invokePNNV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2);
        void invokePNPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2);
        void invokePPNV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2);
        void invokePPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        void invokePPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, long param3);
        void invokePPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void invokePPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void invokePPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3);
        void invokeJJJV(MemorySegment __functionAddress, int param0, int param1, long param2, long param3, long param4);
        void invokePNNV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3, long param4);
        void invokePPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        void invokePPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, boolean param3, boolean param4);
        void invokePPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        void invokePPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        void invokePPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void invokePPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, boolean param4, boolean param5);
        void invokePPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4, int param5, int param6);
        void invokePNPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void invokePPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void invokePJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2, long param3, @FFMNullable @FFMPointer long param4);
        void invokePPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        void invokePJJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, long param3, long param4, long param5);
        void invokePPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        void invokePPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        boolean invokeZ(MemorySegment __functionAddress, int param0);
        boolean invokePZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        boolean invokePZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        boolean invokePZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, boolean param1);
        boolean invokePZ(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2);
        boolean invokePZ(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, boolean param2);
        boolean invokePZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        boolean invokePZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3);
        boolean invokePPZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1);
        boolean invokePPZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2);
        boolean invokePPZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3);
        boolean invokePPPZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        boolean invokePPPZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3);
        boolean invokePPPPZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        boolean invokePPPPZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        boolean invokePPPUPZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, byte param3, @FFMNullable @FFMPointer long param4);
        short callC(MemorySegment __functionAddress, int param0);
        float callF(MemorySegment __functionAddress, int param0, int param1, int param2);
        int callI(MemorySegment __functionAddress);
        int callI(MemorySegment __functionAddress, int param0);
        int callI(MemorySegment __functionAddress, int param0, int param1);
        int callPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        int callPI(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1);
        int callPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, float param1);
        int callPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        int callPI(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2);
        int callPI(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2);
        int callPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        int callPI(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3);
        int callPI(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4);
        int callPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4);
        int callPI(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        int callPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5, int param6);
        int callPI(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, int param6, float param7);
        int callPJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1);
        int callPJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2);
        int callPJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2);
        int callPPI(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, float param2);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2);
        int callPPI(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, int param3, int param4);
        int callPPI(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2, int param3, float param4, @FFMNullable @FFMPointer long param5);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5, int param6, @FFMNullable @FFMPointer long param7);
        int callPPI(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, int param4, int param5, int param6, int param7, float param8);
        int callPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5, int param6, @FFMNullable @FFMPointer long param7, int param8, int param9, int param10, int param11, int param12, int param13, int param14, int param15, int param16);
        int callPJPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2);
        int callPPJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2);
        int callPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        int callPJPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2, @FFMNullable @FFMPointer long param3);
        int callPJPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, @FFMNullable @FFMPointer long param3);
        int callPPJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, long param3);
        int callPPNI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, long param3);
        int callPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        int callPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3);
        int callPJJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, long param3, int param4);
        int callPPJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3, long param4);
        int callPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        int callPJJJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3);
        int callPJPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        int callPPNPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2, @FFMNullable @FFMPointer long param3);
        int callPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        int callPJJJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2, long param3, long param4);
        int callPJPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        int callPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        int callPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4);
        int callPJPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        int callPPPPI(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int param11, int param12, int param13, int param14, int param15, int param16, int param17, int param18, int param19, int param20, @FFMNullable @FFMPointer long param21, @FFMNullable @FFMPointer long param22);
        int callPJPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        int callPPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        int callPJJJPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3, int param4, @FFMNullable @FFMPointer long param5);
        int callPJPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        int callPPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        int callPPPPPI(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        int callPPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        int callJPPPPI(MemorySegment __functionAddress, int param0, int param1, long param2, @FFMNullable @FFMPointer long param3, int param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
        int callPJPPJI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, long param6, int param7);
        int callPJJJJPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3, long param4, @FFMNullable @FFMPointer long param5);
        int callPPPPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        int callPJJPPPI(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        int callPPPPPPI(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
        long callJ(MemorySegment __functionAddress, int param0);
        long callJ(MemorySegment __functionAddress, int param0, int param1);
        long callJ(MemorySegment __functionAddress, int param0, int param1, boolean param2, int param3, int param4);
        long callPJ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        long callPPJ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1);
        long callPJJ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3);
        long callPJJJ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2);
        long callPN(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        @FFMPointer long callP(MemorySegment __functionAddress);
        @FFMPointer long callP(MemorySegment __functionAddress, int param0);
        @FFMPointer long callP(MemorySegment __functionAddress, int param0, int param1);
        @FFMPointer long callP(MemorySegment __functionAddress, int param0, float param1, float param2, float param3);
        @FFMPointer long callPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        @FFMPointer long callPP(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1);
        @FFMPointer long callPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        @FFMPointer long callPP(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2);
        @FFMPointer long callPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        @FFMPointer long callPNP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1);
        @FFMPointer long callPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1);
        @FFMPointer long callPPP(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        @FFMPointer long callPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2);
        @FFMPointer long callPPP(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3);
        @FFMPointer long callPPP(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        @FFMPointer long callPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4);
        @FFMPointer long callPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, int param3, int param4);
        @FFMPointer long callPPNP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2);
        @FFMPointer long callPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        @FFMPointer long callPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        @FFMPointer long callPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3);
        @FFMPointer long callPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, int param3, @FFMNullable @FFMPointer long param4);
        @FFMPointer long callPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3, int param4);
        @FFMPointer long callPPNPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2, @FFMNullable @FFMPointer long param3);
        @FFMPointer long callPPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        @FFMPointer long callPPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4);
        @FFMPointer long callPPPPP(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, int param4);
        @FFMPointer long callPPPPPPPP(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, int param6, @FFMNullable @FFMPointer long param7, @FFMNullable @FFMPointer long param8, @FFMNullable @FFMPointer long param9, int param10, @FFMNullable @FFMPointer long param11, @FFMNullable @FFMPointer long param12);
        short callS(MemorySegment __functionAddress, int param0);
        void callV(MemorySegment __functionAddress);
        void callV(MemorySegment __functionAddress, double param0);
        void callV(MemorySegment __functionAddress, float param0);
        void callV(MemorySegment __functionAddress, int param0);
        void callV(MemorySegment __functionAddress, boolean param0);
        void callV(MemorySegment __functionAddress, double param0, double param1);
        void callV(MemorySegment __functionAddress, float param0, float param1);
        void callV(MemorySegment __functionAddress, float param0, boolean param1);
        void callV(MemorySegment __functionAddress, int param0, double param1);
        void callV(MemorySegment __functionAddress, int param0, float param1);
        void callV(MemorySegment __functionAddress, int param0, int param1);
        void callV(MemorySegment __functionAddress, int param0, boolean param1);
        void callV(MemorySegment __functionAddress, double param0, double param1, double param2);
        void callV(MemorySegment __functionAddress, float param0, float param1, float param2);
        void callV(MemorySegment __functionAddress, int param0, double param1, double param2);
        void callV(MemorySegment __functionAddress, int param0, float param1, float param2);
        void callV(MemorySegment __functionAddress, int param0, int param1, double param2);
        void callV(MemorySegment __functionAddress, int param0, int param1, float param2);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2);
        void callV(MemorySegment __functionAddress, int param0, int param1, boolean param2);
        void callV(MemorySegment __functionAddress, double param0, double param1, double param2, double param3);
        void callV(MemorySegment __functionAddress, float param0, float param1, float param2, float param3);
        void callV(MemorySegment __functionAddress, int param0, double param1, double param2, double param3);
        void callV(MemorySegment __functionAddress, int param0, float param1, float param2, float param3);
        void callV(MemorySegment __functionAddress, int param0, int param1, double param2, double param3);
        void callV(MemorySegment __functionAddress, int param0, int param1, float param2, float param3);
        void callV(MemorySegment __functionAddress, int param0, int param1, float param2, int param3);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, double param3);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, float param3);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, boolean param3);
        void callV(MemorySegment __functionAddress, int param0, int param1, boolean param2, int param3);
        void callV(MemorySegment __functionAddress, boolean param0, boolean param1, boolean param2, boolean param3);
        void callV(MemorySegment __functionAddress, int param0, double param1, double param2, double param3, double param4);
        void callV(MemorySegment __functionAddress, int param0, float param1, float param2, float param3, float param4);
        void callV(MemorySegment __functionAddress, int param0, int param1, double param2, double param3, double param4);
        void callV(MemorySegment __functionAddress, int param0, int param1, float param2, float param3, float param4);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, float param3, int param4);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, boolean param3, int param4);
        void callV(MemorySegment __functionAddress, int param0, boolean param1, boolean param2, boolean param3, boolean param4);
        void callV(MemorySegment __functionAddress, double param0, double param1, double param2, double param3, double param4, double param5);
        void callV(MemorySegment __functionAddress, int param0, double param1, double param2, int param3, double param4, double param5);
        void callV(MemorySegment __functionAddress, int param0, float param1, float param2, int param3, float param4, float param5);
        void callV(MemorySegment __functionAddress, int param0, int param1, double param2, double param3, double param4, double param5);
        void callV(MemorySegment __functionAddress, int param0, int param1, float param2, float param3, float param4, float param5);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, boolean param5);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, boolean param4, int param5);
        void callV(MemorySegment __functionAddress, int param0, double param1, double param2, double param3, double param4, double param5, double param6);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, double param3, double param4, double param5, double param6);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, float param3, float param4, float param5, float param6);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, boolean param6);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, boolean param3, int param4, int param5, int param6);
        void callV(MemorySegment __functionAddress, float param0, float param1, float param2, float param3, float param4, float param5, float param6, float param7);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, boolean param7);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, boolean param8);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9);
        void callV(MemorySegment __functionAddress, int param0, int param1, float param2, float param3, float param4, float param5, float param6, float param7, float param8, float param9, float param10);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int param11);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int param11, int param12, int param13, int param14);
        void callV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int param11, int param12, int param13, int param14, int param15, int param16);
        void callJV(MemorySegment __functionAddress, long param0);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        void callSV(MemorySegment __functionAddress, short param0);
        void callUV(MemorySegment __functionAddress, byte param0);
        void callCV(MemorySegment __functionAddress, int param0, short param1);
        void callJV(MemorySegment __functionAddress, int param0, long param1);
        void callJV(MemorySegment __functionAddress, long param0, int param1);
        void callPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, float param1);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1);
        void callSV(MemorySegment __functionAddress, int param0, short param1);
        void callJV(MemorySegment __functionAddress, int param0, int param1, long param2);
        void callPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2);
        void callPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, float param1, float param2);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2);
        void callJV(MemorySegment __functionAddress, int param0, long param1, int param2, int param3);
        void callNV(MemorySegment __functionAddress, long param0, int param1, int param2, int param3);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3);
        void callPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3);
        void callPV(MemorySegment __functionAddress, int param0, int param1, boolean param2, @FFMNullable @FFMPointer long param3);
        void callPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2, int param3);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, float param1, float param2, float param3);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, int param4);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, boolean param4);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, boolean param3, @FFMNullable @FFMPointer long param4);
        void callPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4);
        void callPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2, int param3, int param4);
        void callPV(MemorySegment __functionAddress, int param0, boolean param1, int param2, int param3, @FFMNullable @FFMPointer long param4);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4);
        void callJV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, long param5);
        void callPV(MemorySegment __functionAddress, int param0, double param1, double param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPV(MemorySegment __functionAddress, int param0, float param1, float param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4, boolean param5);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, int param4, int param5);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, boolean param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5);
        void callPV(MemorySegment __functionAddress, int param0, boolean param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5);
        void callJV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, long param6);
        void callPV(MemorySegment __functionAddress, int param0, int param1, float param2, float param3, float param4, float param5, @FFMNullable @FFMPointer long param6);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5, int param6);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, int param4, int param5, int param6);
        void callPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, int param6);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5, int param6);
        void callJV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, long param7);
        void callJV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, boolean param5, int param6, long param7);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, @FFMNullable @FFMPointer long param7);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, boolean param5, int param6, @FFMNullable @FFMPointer long param7);
        void callJV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, boolean param6, int param7, long param8);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, @FFMNullable @FFMPointer long param8);
        void callPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, int param6, int param7, float param8);
        void callPV(MemorySegment __functionAddress, int param0, double param1, double param2, int param3, int param4, double param5, double param6, int param7, int param8, @FFMNullable @FFMPointer long param9);
        void callPV(MemorySegment __functionAddress, int param0, float param1, float param2, int param3, int param4, float param5, float param6, int param7, int param8, @FFMNullable @FFMPointer long param9);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, @FFMNullable @FFMPointer long param9);
        void callJV(MemorySegment __functionAddress, long param0, int param1, float param2, float param3, float param4, float param5, float param6, float param7, float param8, float param9, float param10);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, @FFMNullable @FFMPointer long param10);
        void callPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10);
        void callJV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, long param10, boolean param11);
        void callPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, @FFMNullable @FFMPointer long param11);
        void callPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1);
        void callPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1);
        void callSSV(MemorySegment __functionAddress, short param0, short param1);
        void callJJV(MemorySegment __functionAddress, int param0, long param1, long param2);
        void callPCV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, short param2);
        void callPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2);
        void callPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, float param2);
        void callPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2);
        void callPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        void callPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2);
        void callPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2);
        void callSSV(MemorySegment __functionAddress, int param0, short param1, short param2);
        void callJJV(MemorySegment __functionAddress, int param0, int param1, long param2, long param3);
        void callJPV(MemorySegment __functionAddress, int param0, int param1, long param2, @FFMNullable @FFMPointer long param3);
        void callJPV(MemorySegment __functionAddress, int param0, long param1, int param2, @FFMNullable @FFMPointer long param3);
        void callPJV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2, long param3);
        void callPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2, int param3);
        void callPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void callPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3);
        void callPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3);
        void callPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, boolean param3);
        void callPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3);
        void callPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, int param3);
        void callPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3, int param4);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, int param4);
        void callPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3, int param4);
        void callPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, int param4);
        void callPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, int param4, int param5);
        void callPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5);
        void callPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, int param4, int param5, @FFMNullable @FFMPointer long param6);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, int param4, int param5, int param6);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4, int param5, int param6, @FFMNullable @FFMPointer long param7);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, int param6, @FFMNullable @FFMPointer long param7);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, int param4, float param5, float param6, int param7, @FFMNullable @FFMPointer long param8);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, int param6, int param7, @FFMNullable @FFMPointer long param8);
        void callPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6, int param7, int param8, float param9);
        void callBBBV(MemorySegment __functionAddress, byte param0, byte param1, byte param2);
        void callCCCV(MemorySegment __functionAddress, short param0, short param1, short param2);
        void callPJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2);
        void callPJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2);
        void callPPNV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2);
        void callPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        void callSSSV(MemorySegment __functionAddress, short param0, short param1, short param2);
        void callUUUV(MemorySegment __functionAddress, byte param0, byte param1, byte param2);
        void callJJJV(MemorySegment __functionAddress, int param0, long param1, long param2, long param3);
        void callPJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, int param3);
        void callPJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, @FFMNullable @FFMPointer long param3);
        void callPPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void callPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void callPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3);
        void callSSSV(MemorySegment __functionAddress, int param0, short param1, short param2, short param3);
        void callJJJV(MemorySegment __functionAddress, int param0, int param1, long param2, long param3, long param4);
        void callPJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2, long param3, int param4);
        void callPJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, int param3, int param4);
        void callPPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        void callPPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        void callPPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4);
        void callPPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, int param4);
        void callPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        void callPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4);
        void callPJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPPJV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, long param4, boolean param5);
        void callPPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3, long param4, int param5);
        void callPPPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        void callPPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        void callPPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, int param2, @FFMNullable @FFMPointer long param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, long param3, long param4, int param5, int param6);
        void callPPPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        void callPPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, int param4, int param5, @FFMNullable @FFMPointer long param6);
        void callPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6);
        void callPPPV(MemorySegment __functionAddress, int param0, int param1, int param2, int param3, @FFMNullable @FFMPointer long param4, int param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
        void callPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
        void callPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, int param2, int param3, int param4, int param5, int param6, int param7, @FFMNullable @FFMPointer long param8, int param9, int param10, int param11, int param12, int param13, int param14, int param15, int param16, int param17);
        void callBBBBV(MemorySegment __functionAddress, byte param0, byte param1, byte param2, byte param3);
        void callCCCCV(MemorySegment __functionAddress, short param0, short param1, short param2, short param3);
        void callPJJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3);
        void callPJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, @FFMNullable @FFMPointer long param3);
        void callPJPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void callPPPNV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, long param3);
        void callPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3);
        void callSSSSV(MemorySegment __functionAddress, short param0, short param1, short param2, short param3);
        void callUUUUV(MemorySegment __functionAddress, byte param0, byte param1, byte param2, byte param3);
        void callJJJJV(MemorySegment __functionAddress, int param0, long param1, long param2, long param3, long param4);
        void callPJJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3, int param4);
        void callPJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2, long param3, @FFMNullable @FFMPointer long param4);
        void callPJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, int param3, @FFMNullable @FFMPointer long param4);
        void callPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4);
        void callPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, int param4);
        void callSSSSV(MemorySegment __functionAddress, int param0, short param1, short param2, short param3, short param4);
        void callUUUUV(MemorySegment __functionAddress, int param0, byte param1, byte param2, byte param3, byte param4);
        void callJJJJV(MemorySegment __functionAddress, int param0, int param1, long param2, long param3, long param4, long param5);
        void callPJJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3, int param4, int param5);
        void callPJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, long param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, int param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPJPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, @FFMNullable @FFMPointer long param3, int param4, @FFMNullable @FFMPointer long param5);
        void callPPPPV(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, int param5);
        void callPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        void callPJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3, long param4, int param5, @FFMNullable @FFMPointer long param6);
        void callPJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, long param3, int param4, int param5, @FFMNullable @FFMPointer long param6);
        void callPJPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2, int param3, int param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        void callPPPPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        void callPPPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, int param6);
        void callPJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, long param3, int param4, int param5, @FFMNullable @FFMPointer long param6, int param7);
        void callPJPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, long param2, int param3, int param4, @FFMNullable @FFMPointer long param5, int param6, @FFMNullable @FFMPointer long param7);
        void callPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, int param3, int param4, @FFMNullable @FFMPointer long param5, int param6, @FFMNullable @FFMPointer long param7, int param8, @FFMNullable @FFMPointer long param9);
        void callPJJJPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3, @FFMNullable @FFMPointer long param4);
        void callPPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5);
        void callPJJJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3, long param4, int param5, int param6);
        void callPPPPPV(MemorySegment __functionAddress, int param0, int param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        void callPPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6);
        void callPJJJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, int param2, int param3, long param4, long param5, long param6, int param7);
        void callPJPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, int param2, long param3, @FFMNullable @FFMPointer long param4, int param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
        void callPPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, int param5, int param6, int param7);
        void callPPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, int param1, @FFMNullable @FFMPointer long param2, int param3, int param4, int param5, @FFMNullable @FFMPointer long param6, int param7, @FFMNullable @FFMPointer long param8, int param9, @FFMNullable @FFMPointer long param10);
        void callPPPPPJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, @FFMNullable @FFMPointer long param3, @FFMNullable @FFMPointer long param4, long param5);
        void callPPPPPPV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2, int param3, int param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
        void callPPPPPPPV(MemorySegment __functionAddress, int param0, int param1, int param2, @FFMNullable @FFMPointer long param3, int param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7, @FFMNullable @FFMPointer long param8, @FFMNullable @FFMPointer long param9, @FFMNullable @FFMPointer long param10);
        void callPPJJJJJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, @FFMNullable @FFMPointer long param1, long param2, long param3, int param4, long param5, long param6, long param7, long param8);
        void callPJJJJJJJJJJJV(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0, long param1, long param2, long param3, long param4, long param5, long param6, long param7, long param8, long param9, long param10, long param11, int param12, int param13, int param14);
        boolean callZ(MemorySegment __functionAddress, int param0);
        boolean callZ(MemorySegment __functionAddress, int param0, int param1);
        boolean callZ(MemorySegment __functionAddress, int param0, float param1, float param2);
        boolean callZ(MemorySegment __functionAddress, int param0, int param1, float param2, float param3);
        boolean callJZ(MemorySegment __functionAddress, long param0);
        boolean callPZ(MemorySegment __functionAddress, @FFMNullable @FFMPointer long param0);
        boolean callJZ(MemorySegment __functionAddress, int param0, long param1);
        boolean callPZ(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1);
        boolean callJZ(MemorySegment __functionAddress, int param0, long param1, int param2);
        boolean callPPZ(MemorySegment __functionAddress, int param0, @FFMNullable @FFMPointer long param1, @FFMNullable @FFMPointer long param2);
        boolean callPPPPZ(MemorySegment __functionAddress, int param0, int param1, int param2, float param3, @FFMNullable @FFMPointer long param4, @FFMNullable @FFMPointer long param5, @FFMNullable @FFMPointer long param6, @FFMNullable @FFMPointer long param7);
    }

    /*
    private static final TraceConsumer TRACER = (method, returnValue, args) -> {
        var prefix = method.getDeclaringClass().getAnnotation(FFMPrefix.class);
        if (prefix != null) {
            System.err.print(prefix.value());
        }
        System.err.println(method.getName() + '(' + Stream.of(args)
            .skip(1)
            .map(JNI::render)
            .collect(Collectors.joining(", ")) + ")" + (returnValue == null ? "" : " : " + render(returnValue)));
    };

    private static String render(Object value) {
        if (value instanceof MemorySegment segment) {
            return "0x" + Long.toHexString(segment.address()) + (segment.byteSize() == 0 ? "" : (" [" + (segment.byteSize() == Long.MAX_VALUE ? "?" : segment.byteSize()) + "]"));
        } else {
            return value.toString();
        }
    }*/

    /*private static int count;
    private static long lastT = System.nanoTime();
    private static final TraceConsumer TRACER = (_, _, _) -> {
        count++;
        long t = System.nanoTime();
        if (t - lastT > 1_000_000_000L) {
            System.err.println("JNI calls: " + count + "/s");
            lastT = t;
            count = 0;
        }
    };*/

    private static final JNIBindings jni = ffmGenerate(
        JNIBindings.class,
        ffmConfigBuilder(MethodHandles.lookup())
            .withChecks(false)
            //.withCriticalOverride(_ -> true)
            //.withTracing(TRACER)
            .build()
    );

    private JNI() {}

    // Pointer API

    public static short invokePC(long param0, long __functionAddress) { return jni.invokePC(MemorySegment.ofAddress(__functionAddress), param0); }
    public static double invokeD(long __functionAddress) { return jni.invokeD(MemorySegment.ofAddress(__functionAddress)); }
    public static double invokeD(int param0, long __functionAddress) { return jni.invokeD(MemorySegment.ofAddress(__functionAddress), param0); }
    public static double invokePD(long param0, int param1, long __functionAddress) { return jni.invokePD(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static double invokePD(long param0, int param1, int param2, long __functionAddress) { return jni.invokePD(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static float invokeF(int param0, long __functionAddress) { return jni.invokeF(MemorySegment.ofAddress(__functionAddress), param0); }
    public static float invokePF(long param0, long __functionAddress) { return jni.invokePF(MemorySegment.ofAddress(__functionAddress), param0); }
    public static float invokePF(float param0, long param1, long __functionAddress) { return jni.invokePF(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static float invokePF(long param0, int param1, long __functionAddress) { return jni.invokePF(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static float invokePF(float param0, float param1, long param2, long __functionAddress) { return jni.invokePF(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static float invokePF(long param0, int param1, int param2, long __functionAddress) { return jni.invokePF(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokeI(long __functionAddress) { return jni.invokeI(MemorySegment.ofAddress(__functionAddress)); }
    public static int invokeI(int param0, long __functionAddress) { return jni.invokeI(MemorySegment.ofAddress(__functionAddress), param0); }
    public static int invokeI(int param0, int param1, long __functionAddress) { return jni.invokeI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int invokePI(long param0, long __functionAddress) { return jni.invokePI(MemorySegment.ofAddress(__functionAddress), param0); }
    public static int invokePI(int param0, long param1, long __functionAddress) { return jni.invokePI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int invokePI(long param0, int param1, long __functionAddress) { return jni.invokePI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int invokePI(long param0, int param1, int param2, long __functionAddress) { return jni.invokePI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePI(long param0, int param1, boolean param2, long __functionAddress) { return jni.invokePI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePI(long param0, int param1, int param2, int param3, long __functionAddress) { return jni.invokePI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePI(long param0, int param1, int param2, int param3, int param4, int param5, int param6, long __functionAddress) { return jni.invokePI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static int invokePNI(long param0, long param1, long __functionAddress) { return jni.invokePNI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int invokePPI(long param0, long param1, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int invokePNI(long param0, long param1, int param2, long __functionAddress) { return jni.invokePNI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePPI(int param0, long param1, long param2, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePPI(long param0, int param1, long param2, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePPI(long param0, long param1, int param2, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePPI(long param0, long param1, boolean param2, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePPI(long param0, boolean param1, long param2, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePPI(long param0, int param1, int param2, long param3, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPI(long param0, int param1, long param2, int param3, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPI(long param0, int param1, long param2, boolean param3, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPI(long param0, int param1, boolean param2, long param3, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPI(long param0, long param1, int param2, int param3, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPI(long param0, long param1, boolean param2, boolean param3, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPI(long param0, int param1, int param2, int param3, long param4, long __functionAddress) { return jni.invokePPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePCPI(long param0, short param1, long param2, long __functionAddress) { return jni.invokePCPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePNNI(long param0, long param1, long param2, long __functionAddress) { return jni.invokePNNI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePNPI(long param0, long param1, long param2, long __functionAddress) { return jni.invokePNPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePPPI(long param0, long param1, long param2, long __functionAddress) { return jni.invokePPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int invokePNPI(long param0, long param1, int param2, long param3, long __functionAddress) { return jni.invokePNPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPPI(long param0, int param1, long param2, long param3, long __functionAddress) { return jni.invokePPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPPI(long param0, long param1, int param2, long param3, long __functionAddress) { return jni.invokePPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPPI(long param0, long param1, long param2, int param3, long __functionAddress) { return jni.invokePPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePNNI(long param0, long param1, long param2, int param3, int param4, long __functionAddress) { return jni.invokePNNI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePPPI(long param0, int param1, int param2, long param3, long param4, long __functionAddress) { return jni.invokePPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePPPI(long param0, int param1, long param2, int param3, long param4, long __functionAddress) { return jni.invokePPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePPNNI(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.invokePPNNI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPNPI(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.invokePPNPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePPPPI(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.invokePPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int invokePNNPI(long param0, long param1, int param2, long param3, long param4, long __functionAddress) { return jni.invokePNNPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePPPPI(long param0, long param1, int param2, long param3, long param4, long __functionAddress) { return jni.invokePPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePNNPPI(long param0, long param1, long param2, long param3, long param4, long __functionAddress) { return jni.invokePNNPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePPNNPI(long param0, long param1, long param2, long param3, long param4, long __functionAddress) { return jni.invokePPNNPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePPPPNI(long param0, long param1, long param2, long param3, long param4, long __functionAddress) { return jni.invokePPPPNI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePPPPPI(long param0, long param1, long param2, long param3, long param4, long __functionAddress) { return jni.invokePPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int invokePPNPPI(long param0, long param1, long param2, int param3, long param4, long param5, long __functionAddress) { return jni.invokePPNPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int invokePPPPPI(long param0, long param1, long param2, int param3, long param4, long param5, long __functionAddress) { return jni.invokePPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int invokePNPPPI(long param0, int param1, int param2, long param3, long param4, long param5, long param6, long __functionAddress) { return jni.invokePNPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static int invokePPPPPPI(long param0, long param1, long param2, long param3, long param4, long param5, long __functionAddress) { return jni.invokePPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int invokePPPPPPI(long param0, int param1, long param2, long param3, long param4, long param5, long param6, long __functionAddress) { return jni.invokePPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static int invokePNNPPPI(long param0, long param1, long param2, int param3, int param4, long param5, long param6, long param7, long __functionAddress) { return jni.invokePNNPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static int invokePPPPPPI(int param0, int param1, long param2, long param3, long param4, long param5, long param6, long param7, long __functionAddress) { return jni.invokePPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static int invokePPPPPPPI(long param0, long param1, long param2, long param3, long param4, long param5, long param6, long __functionAddress) { return jni.invokePPPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static int invokePPPPPPPI(long param0, int param1, int param2, long param3, long param4, long param5, long param6, long param7, long param8, long __functionAddress) { return jni.invokePPPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static long invokeJ(long __functionAddress) { return jni.invokeJ(MemorySegment.ofAddress(__functionAddress)); }
    public static long invokePJ(long param0, long __functionAddress) { return jni.invokePJ(MemorySegment.ofAddress(__functionAddress), param0); }
    public static long invokePJ(long param0, int param1, long __functionAddress) { return jni.invokePJ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long invokePJ(long param0, int param1, int param2, long __functionAddress) { return jni.invokePJ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long invokeNN(long param0, long __functionAddress) { return jni.invokeNN(MemorySegment.ofAddress(__functionAddress), param0); }
    public static long invokePN(long param0, long __functionAddress) { return jni.invokePN(MemorySegment.ofAddress(__functionAddress), param0); }
    public static long invokePN(long param0, int param1, long __functionAddress) { return jni.invokePN(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long invokeNNN(long param0, long param1, long __functionAddress) { return jni.invokeNNN(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long invokePPN(long param0, long param1, long __functionAddress) { return jni.invokePPN(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long invokeNNNN(long param0, long param1, long param2, long __functionAddress) { return jni.invokeNNNN(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long invokePNPN(long param0, long param1, long param2, long __functionAddress) { return jni.invokePNPN(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long invokePNPN(long param0, long param1, long param2, int param3, long __functionAddress) { return jni.invokePNPN(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long invokePPNN(long param0, int param1, int param2, long param3, long param4, long __functionAddress) { return jni.invokePPNN(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long invokePNPNN(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.invokePNPNN(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long invokePNPNPN(long param0, long param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, long param9, long param10, long param11, long __functionAddress) { return jni.invokePNPNPN(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11); }
    public static long invokeP(long __functionAddress) { return jni.invokeP(MemorySegment.ofAddress(__functionAddress)); }
    public static long invokeP(int param0, long __functionAddress) { return jni.invokeP(MemorySegment.ofAddress(__functionAddress), param0); }
    public static long invokeP(int param0, int param1, long __functionAddress) { return jni.invokeP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long invokePP(long param0, long __functionAddress) { return jni.invokePP(MemorySegment.ofAddress(__functionAddress), param0); }
    public static long invokePP(int param0, long param1, long __functionAddress) { return jni.invokePP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long invokePP(long param0, int param1, long __functionAddress) { return jni.invokePP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long invokePP(long param0, int param1, int param2, long __functionAddress) { return jni.invokePP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long invokePP(long param0, int param1, int param2, int param3, long __functionAddress) { return jni.invokePP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long invokePP(long param0, int param1, int param2, int param3, int param4, int param5, long __functionAddress) { return jni.invokePP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static long invokePNP(long param0, long param1, long __functionAddress) { return jni.invokePNP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long invokePPP(long param0, long param1, long __functionAddress) { return jni.invokePPP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long invokePCP(long param0, short param1, boolean param2, long __functionAddress) { return jni.invokePCP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long invokePPP(long param0, int param1, long param2, long __functionAddress) { return jni.invokePPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long invokePPP(long param0, long param1, int param2, long __functionAddress) { return jni.invokePPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long invokePPP(long param0, int param1, long param2, int param3, long __functionAddress) { return jni.invokePPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long invokePPP(long param0, long param1, boolean param2, boolean param3, long __functionAddress) { return jni.invokePPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long invokePPP(long param0, boolean param1, boolean param2, long param3, long __functionAddress) { return jni.invokePPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long invokePPPP(long param0, long param1, long param2, long __functionAddress) { return jni.invokePPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long invokePPPP(long param0, int param1, long param2, long param3, long __functionAddress) { return jni.invokePPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long invokePPPP(int param0, int param1, long param2, long param3, long param4, long __functionAddress) { return jni.invokePPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long invokeJPPP(int param0, int param1, int param2, long param3, long param4, long param5, long __functionAddress) { return jni.invokeJPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static long invokePNNPP(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.invokePNNPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long invokePPPPP(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.invokePPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long invokePPPPP(long param0, long param1, int param2, long param3, long param4, long __functionAddress) { return jni.invokePPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long invokePJPPP(long param0, int param1, int param2, long param3, long param4, long param5, long __functionAddress) { return jni.invokePJPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static long invokePNNNPP(long param0, long param1, long param2, long param3, long param4, long __functionAddress) { return jni.invokePNNNPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long invokePPPPPPP(long param0, long param1, long param2, int param3, long param4, long param5, long param6, long __functionAddress) { return jni.invokePPPPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void invokeV(long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress)); }
    public static void invokeV(double param0, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void invokeV(float param0, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void invokeV(int param0, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void invokeV(int param0, float param1, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokeV(int param0, int param1, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokeV(int param0, int param1, double param2, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokeV(int param0, int param1, float param2, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokeV(int param0, int param1, int param2, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokeV(int param0, float param1, float param2, float param3, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokeV(int param0, int param1, int param2, int param3, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokeV(int param0, int param1, double param2, double param3, double param4, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokeV(int param0, int param1, float param2, float param3, float param4, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokeV(int param0, int param1, int param2, int param3, int param4, long __functionAddress) { jni.invokeV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePV(long param0, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void invokeJV(int param0, long param1, long __functionAddress) { jni.invokeJV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokePV(int param0, long param1, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokePV(long param0, float param1, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokePV(long param0, int param1, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokePV(long param0, boolean param1, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokeJV(int param0, int param1, long param2, long __functionAddress) { jni.invokeJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePV(int param0, int param1, long param2, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePV(int param0, long param1, boolean param2, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePV(long param0, double param1, double param2, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePV(long param0, float param1, float param2, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePV(long param0, int param1, double param2, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePV(long param0, int param1, float param2, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePV(long param0, int param1, int param2, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePV(int param0, int param1, int param2, long param3, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePV(long param0, int param1, int param2, double param3, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePV(long param0, int param1, int param2, float param3, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePV(long param0, int param1, int param2, int param3, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePV(int param0, int param1, long param2, int param3, int param4, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePV(long param0, int param1, float param2, float param3, float param4, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePV(long param0, int param1, int param2, int param3, int param4, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePV(int param0, int param1, int param2, int param3, int param4, long param5, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePV(int param0, int param1, int param2, int param3, long param4, boolean param5, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePV(long param0, int param1, int param2, double param3, double param4, double param5, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePV(long param0, int param1, int param2, float param3, float param4, float param5, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePV(long param0, int param1, int param2, int param3, int param4, int param5, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePV(int param0, int param1, int param2, int param3, int param4, int param5, long param6, long __functionAddress) { jni.invokePV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void invokePJV(long param0, long param1, long __functionAddress) { jni.invokePJV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokePNV(long param0, long param1, long __functionAddress) { jni.invokePNV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokePPV(long param0, long param1, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void invokePJV(int param0, long param1, long param2, long __functionAddress) { jni.invokePJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePJV(long param0, int param1, long param2, long __functionAddress) { jni.invokePJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePPV(long param0, int param1, long param2, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePPV(long param0, long param1, int param2, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePPV(long param0, long param1, boolean param2, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePBV(long param0, int param1, int param2, byte param3, long __functionAddress) { jni.invokePBV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePCV(long param0, int param1, int param2, short param3, long __functionAddress) { jni.invokePCV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePJV(long param0, int param1, int param2, long param3, long __functionAddress) { jni.invokePJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePPV(int param0, int param1, long param2, long param3, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePPV(long param0, int param1, int param2, long param3, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePPV(long param0, int param1, long param2, boolean param3, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePSV(long param0, int param1, int param2, short param3, long __functionAddress) { jni.invokePSV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePUV(long param0, int param1, int param2, byte param3, long __functionAddress) { jni.invokePUV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePPV(int param0, int param1, int param2, long param3, long param4, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePPV(long param0, int param1, int param2, int param3, long param4, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePPV(int param0, int param1, int param2, int param3, long param4, long param5, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePPV(long param0, int param1, int param2, long param3, int param4, int param5, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePPV(int param0, int param1, int param2, int param3, int param4, long param5, long param6, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void invokePPV(long param0, int param1, int param2, int param3, int param4, int param5, long param6, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void invokePPV(long param0, int param1, int param2, int param3, int param4, long param5, boolean param6, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void invokePPV(long param0, long param1, int param2, int param3, int param4, int param5, int param6, long __functionAddress) { jni.invokePPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void invokePNNV(long param0, long param1, long param2, long __functionAddress) { jni.invokePNNV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePNPV(long param0, long param1, long param2, long __functionAddress) { jni.invokePNPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePPNV(long param0, long param1, long param2, long __functionAddress) { jni.invokePPNV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePPPV(long param0, long param1, long param2, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void invokePPJV(long param0, int param1, long param2, long param3, long __functionAddress) { jni.invokePPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePPPV(int param0, long param1, long param2, long param3, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePPPV(long param0, int param1, long param2, long param3, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePPPV(long param0, long param1, long param2, int param3, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokeJJJV(int param0, int param1, long param2, long param3, long param4, long __functionAddress) { jni.invokeJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePNNV(long param0, long param1, int param2, int param3, long param4, long __functionAddress) { jni.invokePNNV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePPPV(int param0, int param1, long param2, long param3, long param4, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePPPV(long param0, long param1, long param2, boolean param3, boolean param4, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePPPV(int param0, int param1, long param2, int param3, long param4, long param5, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePPPV(long param0, int param1, int param2, int param3, long param4, long param5, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePPPV(long param0, long param1, int param2, int param3, int param4, long param5, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePPPV(long param0, long param1, long param2, int param3, boolean param4, boolean param5, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePPPV(long param0, int param1, long param2, int param3, long param4, int param5, int param6, long __functionAddress) { jni.invokePPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void invokePNPPV(long param0, long param1, long param2, long param3, long __functionAddress) { jni.invokePNPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePPPPV(long param0, long param1, long param2, long param3, long __functionAddress) { jni.invokePPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void invokePJJPV(long param0, int param1, long param2, long param3, long param4, long __functionAddress) { jni.invokePJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePPPPV(long param0, int param1, long param2, long param3, long param4, long __functionAddress) { jni.invokePPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void invokePJJJV(long param0, int param1, int param2, long param3, long param4, long param5, long __functionAddress) { jni.invokePJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePPPPV(long param0, int param1, int param2, long param3, long param4, long param5, long __functionAddress) { jni.invokePPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void invokePPPPPV(long param0, long param1, long param2, long param3, long param4, long __functionAddress) { jni.invokePPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static boolean invokeZ(int param0, long __functionAddress) { return jni.invokeZ(MemorySegment.ofAddress(__functionAddress), param0); }
    public static boolean invokePZ(long param0, long __functionAddress) { return jni.invokePZ(MemorySegment.ofAddress(__functionAddress), param0); }
    public static boolean invokePZ(long param0, int param1, long __functionAddress) { return jni.invokePZ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static boolean invokePZ(long param0, boolean param1, long __functionAddress) { return jni.invokePZ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static boolean invokePZ(int param0, int param1, long param2, long __functionAddress) { return jni.invokePZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static boolean invokePZ(int param0, long param1, boolean param2, long __functionAddress) { return jni.invokePZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static boolean invokePZ(long param0, int param1, int param2, long __functionAddress) { return jni.invokePZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static boolean invokePZ(long param0, int param1, int param2, int param3, long __functionAddress) { return jni.invokePZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static boolean invokePPZ(long param0, long param1, long __functionAddress) { return jni.invokePPZ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static boolean invokePPZ(long param0, int param1, long param2, long __functionAddress) { return jni.invokePPZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static boolean invokePPZ(long param0, int param1, int param2, long param3, long __functionAddress) { return jni.invokePPZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static boolean invokePPPZ(long param0, long param1, long param2, long __functionAddress) { return jni.invokePPPZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static boolean invokePPPZ(long param0, long param1, long param2, int param3, long __functionAddress) { return jni.invokePPPZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static boolean invokePPPPZ(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.invokePPPPZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static boolean invokePPPPZ(long param0, int param1, long param2, long param3, long param4, long __functionAddress) { return jni.invokePPPPZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static boolean invokePPPUPZ(long param0, long param1, long param2, byte param3, long param4, long __functionAddress) { return jni.invokePPPUPZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static short callC(int param0, long __functionAddress) { return jni.callC(MemorySegment.ofAddress(__functionAddress), param0); }
    public static float callF(int param0, int param1, int param2, long __functionAddress) { return jni.callF(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callI(long __functionAddress) { return jni.callI(MemorySegment.ofAddress(__functionAddress)); }
    public static int callI(int param0, long __functionAddress) { return jni.callI(MemorySegment.ofAddress(__functionAddress), param0); }
    public static int callI(int param0, int param1, long __functionAddress) { return jni.callI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int callPI(long param0, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0); }
    public static int callPI(int param0, long param1, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int callPI(long param0, float param1, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int callPI(long param0, int param1, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int callPI(int param0, int param1, long param2, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPI(int param0, long param1, int param2, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPI(long param0, int param1, int param2, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPI(int param0, int param1, int param2, long param3, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPI(int param0, int param1, int param2, int param3, long param4, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPI(long param0, int param1, int param2, int param3, int param4, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPI(int param0, int param1, int param2, int param3, int param4, long param5, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int callPI(long param0, int param1, int param2, int param3, int param4, int param5, int param6, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static int callPI(int param0, int param1, long param2, int param3, int param4, int param5, int param6, float param7, long __functionAddress) { return jni.callPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static int callPJI(long param0, long param1, long __functionAddress) { return jni.callPJI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int callPPI(long param0, long param1, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static int callPJI(long param0, int param1, long param2, long __functionAddress) { return jni.callPJI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPJI(long param0, long param1, int param2, long __functionAddress) { return jni.callPJI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPPI(int param0, long param1, long param2, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPPI(long param0, int param1, long param2, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPPI(long param0, long param1, float param2, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPPI(long param0, long param1, int param2, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPPI(int param0, int param1, long param2, long param3, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPPI(long param0, int param1, int param2, long param3, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPPI(long param0, int param1, long param2, int param3, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPPI(long param0, int param1, int param2, int param3, long param4, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPPI(long param0, long param1, int param2, int param3, int param4, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPPI(int param0, long param1, int param2, int param3, float param4, long param5, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int callPPI(long param0, int param1, int param2, int param3, int param4, int param5, long param6, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static int callPPI(long param0, int param1, int param2, int param3, int param4, int param5, int param6, long param7, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static int callPPI(int param0, int param1, long param2, long param3, int param4, int param5, int param6, int param7, float param8, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static int callPPI(long param0, int param1, int param2, int param3, int param4, int param5, int param6, long param7, int param8, int param9, int param10, int param11, int param12, int param13, int param14, int param15, int param16, long __functionAddress) { return jni.callPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16); }
    public static int callPJPI(long param0, long param1, long param2, long __functionAddress) { return jni.callPJPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPPJI(long param0, long param1, long param2, long __functionAddress) { return jni.callPPJI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPPPI(long param0, long param1, long param2, long __functionAddress) { return jni.callPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static int callPJPI(long param0, int param1, long param2, long param3, long __functionAddress) { return jni.callPJPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPJPI(long param0, long param1, int param2, long param3, long __functionAddress) { return jni.callPJPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPPJI(long param0, int param1, long param2, long param3, long __functionAddress) { return jni.callPPJI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPPNI(long param0, int param1, long param2, long param3, long __functionAddress) { return jni.callPPNI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPPPI(long param0, int param1, long param2, long param3, long __functionAddress) { return jni.callPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPPPI(long param0, long param1, int param2, long param3, long __functionAddress) { return jni.callPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPJJI(long param0, long param1, int param2, long param3, int param4, long __functionAddress) { return jni.callPJJI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPPJI(long param0, int param1, long param2, int param3, long param4, long __functionAddress) { return jni.callPPJI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPPPI(long param0, int param1, int param2, int param3, long param4, long param5, long __functionAddress) { return jni.callPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int callPJJJI(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.callPJJJI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPJPPI(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.callPJPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPPNPI(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.callPPNPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPPPPI(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.callPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static int callPJJJI(long param0, int param1, long param2, long param3, long param4, long __functionAddress) { return jni.callPJJJI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPJPPI(long param0, long param1, int param2, long param3, long param4, long __functionAddress) { return jni.callPJPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPPPPI(long param0, int param1, long param2, long param3, long param4, long __functionAddress) { return jni.callPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPPPPI(long param0, long param1, long param2, int param3, long param4, long __functionAddress) { return jni.callPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPJPPI(long param0, long param1, int param2, int param3, long param4, long param5, long __functionAddress) { return jni.callPJPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int callPPPPI(int param0, long param1, long param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int param11, int param12, int param13, int param14, int param15, int param16, int param17, int param18, int param19, int param20, long param21, long param22, long __functionAddress) { return jni.callPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16, param17, param18, param19, param20, param21, param22); }
    public static int callPJPPPI(long param0, long param1, long param2, long param3, long param4, long __functionAddress) { return jni.callPJPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPPPPPI(long param0, long param1, long param2, long param3, long param4, long __functionAddress) { return jni.callPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static int callPJJJPI(long param0, long param1, long param2, long param3, int param4, long param5, long __functionAddress) { return jni.callPJJJPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int callPJPPPI(long param0, long param1, int param2, long param3, long param4, long param5, long __functionAddress) { return jni.callPJPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int callPPPPPI(long param0, long param1, long param2, int param3, long param4, long param5, long __functionAddress) { return jni.callPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int callPPPPPI(int param0, int param1, long param2, long param3, long param4, long param5, long param6, long __functionAddress) { return jni.callPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static int callPPPPPI(long param0, int param1, long param2, int param3, long param4, long param5, long param6, long __functionAddress) { return jni.callPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static int callJPPPPI(int param0, int param1, long param2, long param3, int param4, long param5, long param6, long param7, long __functionAddress) { return jni.callJPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static int callPJPPJI(long param0, long param1, int param2, int param3, long param4, long param5, long param6, int param7, long __functionAddress) { return jni.callPJPPJI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static int callPJJJJPI(long param0, long param1, long param2, long param3, long param4, long param5, long __functionAddress) { return jni.callPJJJJPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int callPPPPPPI(long param0, long param1, long param2, long param3, long param4, long param5, long __functionAddress) { return jni.callPPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static int callPJJPPPI(long param0, long param1, long param2, int param3, long param4, long param5, long param6, long __functionAddress) { return jni.callPJJPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static int callPPPPPPI(int param0, int param1, long param2, long param3, long param4, long param5, long param6, long param7, long __functionAddress) { return jni.callPPPPPPI(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static long callJ(int param0, long __functionAddress) { return jni.callJ(MemorySegment.ofAddress(__functionAddress), param0); }
    public static long callJ(int param0, int param1, long __functionAddress) { return jni.callJ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long callJ(int param0, int param1, boolean param2, int param3, int param4, long __functionAddress) { return jni.callJ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long callPJ(long param0, int param1, long __functionAddress) { return jni.callPJ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long callPPJ(long param0, long param1, long __functionAddress) { return jni.callPPJ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long callPJJ(long param0, long param1, int param2, int param3, long __functionAddress) { return jni.callPJJ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long callPJJJ(long param0, long param1, long param2, long __functionAddress) { return jni.callPJJJ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long callPN(long param0, long __functionAddress) { return jni.callPN(MemorySegment.ofAddress(__functionAddress), param0); }
    public static long callP(long __functionAddress) { return jni.callP(MemorySegment.ofAddress(__functionAddress)); }
    public static long callP(int param0, long __functionAddress) { return jni.callP(MemorySegment.ofAddress(__functionAddress), param0); }
    public static long callP(int param0, int param1, long __functionAddress) { return jni.callP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long callP(int param0, float param1, float param2, float param3, long __functionAddress) { return jni.callP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long callPP(long param0, long __functionAddress) { return jni.callPP(MemorySegment.ofAddress(__functionAddress), param0); }
    public static long callPP(int param0, long param1, long __functionAddress) { return jni.callPP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long callPP(long param0, int param1, long __functionAddress) { return jni.callPP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long callPP(int param0, long param1, int param2, long __functionAddress) { return jni.callPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long callPP(long param0, int param1, int param2, long __functionAddress) { return jni.callPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long callPNP(long param0, long param1, long __functionAddress) { return jni.callPNP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long callPPP(long param0, long param1, long __functionAddress) { return jni.callPPP(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static long callPPP(int param0, long param1, long param2, long __functionAddress) { return jni.callPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long callPPP(long param0, int param1, long param2, long __functionAddress) { return jni.callPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long callPPP(int param0, long param1, long param2, int param3, long __functionAddress) { return jni.callPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long callPPP(int param0, int param1, int param2, long param3, long param4, long __functionAddress) { return jni.callPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long callPPP(long param0, int param1, int param2, int param3, long param4, long __functionAddress) { return jni.callPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long callPPP(long param0, long param1, int param2, int param3, int param4, long __functionAddress) { return jni.callPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long callPPNP(long param0, long param1, long param2, long __functionAddress) { return jni.callPPNP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long callPPPP(long param0, long param1, long param2, long __functionAddress) { return jni.callPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static long callPPPP(long param0, int param1, long param2, long param3, long __functionAddress) { return jni.callPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long callPPPP(long param0, long param1, long param2, int param3, long __functionAddress) { return jni.callPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long callPPPP(long param0, long param1, int param2, int param3, long param4, long __functionAddress) { return jni.callPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long callPPPP(long param0, long param1, int param2, long param3, int param4, long __functionAddress) { return jni.callPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long callPPNPP(long param0, long param1, long param2, long param3, long __functionAddress) { return jni.callPPNPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static long callPPPPP(long param0, long param1, int param2, long param3, long param4, long __functionAddress) { return jni.callPPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long callPPPPP(long param0, long param1, long param2, int param3, long param4, long __functionAddress) { return jni.callPPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long callPPPPP(long param0, long param1, long param2, long param3, int param4, long __functionAddress) { return jni.callPPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static long callPPPPPPPP(int param0, long param1, long param2, int param3, int param4, int param5, int param6, long param7, long param8, long param9, int param10, long param11, long param12, long __functionAddress) { return jni.callPPPPPPPP(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12); }
    public static short callS(int param0, long __functionAddress) { return jni.callS(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void callV(long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress)); }
    public static void callV(double param0, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void callV(float param0, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void callV(int param0, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void callV(boolean param0, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void callV(double param0, double param1, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callV(float param0, float param1, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callV(float param0, boolean param1, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callV(int param0, double param1, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callV(int param0, float param1, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callV(int param0, int param1, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callV(int param0, boolean param1, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callV(double param0, double param1, double param2, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callV(float param0, float param1, float param2, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callV(int param0, double param1, double param2, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callV(int param0, float param1, float param2, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callV(int param0, int param1, double param2, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callV(int param0, int param1, float param2, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callV(int param0, int param1, int param2, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callV(int param0, int param1, boolean param2, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callV(double param0, double param1, double param2, double param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(float param0, float param1, float param2, float param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, double param1, double param2, double param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, float param1, float param2, float param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, int param1, double param2, double param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, int param1, float param2, float param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, int param1, float param2, int param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, int param1, int param2, double param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, int param1, int param2, float param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, int param1, int param2, int param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, int param1, int param2, boolean param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, int param1, boolean param2, int param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(boolean param0, boolean param1, boolean param2, boolean param3, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callV(int param0, double param1, double param2, double param3, double param4, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callV(int param0, float param1, float param2, float param3, float param4, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callV(int param0, int param1, double param2, double param3, double param4, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callV(int param0, int param1, float param2, float param3, float param4, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callV(int param0, int param1, int param2, float param3, int param4, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callV(int param0, int param1, int param2, boolean param3, int param4, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callV(int param0, boolean param1, boolean param2, boolean param3, boolean param4, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callV(double param0, double param1, double param2, double param3, double param4, double param5, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callV(int param0, double param1, double param2, int param3, double param4, double param5, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callV(int param0, float param1, float param2, int param3, float param4, float param5, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callV(int param0, int param1, double param2, double param3, double param4, double param5, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callV(int param0, int param1, float param2, float param3, float param4, float param5, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, boolean param5, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callV(int param0, int param1, int param2, int param3, boolean param4, int param5, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callV(int param0, double param1, double param2, double param3, double param4, double param5, double param6, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callV(int param0, int param1, int param2, double param3, double param4, double param5, double param6, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callV(int param0, int param1, int param2, float param3, float param4, float param5, float param6, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, boolean param6, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callV(int param0, int param1, int param2, boolean param3, int param4, int param5, int param6, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callV(float param0, float param1, float param2, float param3, float param4, float param5, float param6, float param7, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, boolean param7, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, boolean param8, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9); }
    public static void callV(int param0, int param1, float param2, float param3, float param4, float param5, float param6, float param7, float param8, float param9, float param10, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int param11, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int param11, int param12, int param13, int param14, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14); }
    public static void callV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int param11, int param12, int param13, int param14, int param15, int param16, long __functionAddress) { jni.callV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16); }
    public static void callJV(long param0, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void callPV(long param0, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void callSV(short param0, long __functionAddress) { jni.callSV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void callUV(byte param0, long __functionAddress) { jni.callUV(MemorySegment.ofAddress(__functionAddress), param0); }
    public static void callCV(int param0, short param1, long __functionAddress) { jni.callCV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callJV(int param0, long param1, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callJV(long param0, int param1, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callPV(int param0, long param1, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callPV(long param0, float param1, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callPV(long param0, int param1, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callSV(int param0, short param1, long __functionAddress) { jni.callSV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callJV(int param0, int param1, long param2, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPV(int param0, int param1, long param2, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPV(int param0, long param1, int param2, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPV(long param0, float param1, float param2, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPV(long param0, int param1, int param2, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callJV(int param0, long param1, int param2, int param3, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callNV(long param0, int param1, int param2, int param3, long __functionAddress) { jni.callNV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPV(int param0, int param1, int param2, long param3, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPV(int param0, int param1, long param2, int param3, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPV(int param0, int param1, boolean param2, long param3, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPV(int param0, long param1, int param2, int param3, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPV(long param0, float param1, float param2, float param3, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPV(long param0, int param1, int param2, int param3, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPV(int param0, int param1, int param2, int param3, long param4, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPV(int param0, int param1, int param2, long param3, int param4, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPV(int param0, int param1, int param2, long param3, boolean param4, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPV(int param0, int param1, int param2, boolean param3, long param4, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPV(int param0, int param1, long param2, int param3, int param4, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPV(int param0, long param1, int param2, int param3, int param4, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPV(int param0, boolean param1, int param2, int param3, long param4, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPV(long param0, int param1, int param2, int param3, int param4, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callJV(int param0, int param1, int param2, int param3, int param4, long param5, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPV(int param0, double param1, double param2, int param3, int param4, long param5, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPV(int param0, float param1, float param2, int param3, int param4, long param5, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPV(int param0, int param1, int param2, int param3, int param4, long param5, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPV(int param0, int param1, int param2, int param3, long param4, boolean param5, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPV(int param0, int param1, int param2, long param3, int param4, int param5, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPV(int param0, int param1, int param2, boolean param3, int param4, long param5, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPV(int param0, int param1, long param2, int param3, int param4, int param5, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPV(int param0, boolean param1, int param2, int param3, int param4, long param5, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPV(long param0, int param1, int param2, int param3, int param4, int param5, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callJV(int param0, int param1, int param2, int param3, int param4, int param5, long param6, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPV(int param0, int param1, float param2, float param3, float param4, float param5, long param6, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPV(int param0, int param1, int param2, int param3, int param4, int param5, long param6, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPV(int param0, int param1, int param2, int param3, int param4, long param5, int param6, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPV(int param0, int param1, int param2, long param3, int param4, int param5, int param6, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPV(int param0, int param1, long param2, int param3, int param4, int param5, int param6, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPV(long param0, int param1, int param2, int param3, int param4, int param5, int param6, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callJV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, long param7, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callJV(int param0, int param1, int param2, int param3, int param4, boolean param5, int param6, long param7, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, long param7, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPV(int param0, int param1, int param2, int param3, int param4, boolean param5, int param6, long param7, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callJV(int param0, int param1, int param2, int param3, int param4, int param5, boolean param6, int param7, long param8, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, long param8, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static void callPV(int param0, int param1, long param2, int param3, int param4, int param5, int param6, int param7, float param8, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static void callPV(int param0, double param1, double param2, int param3, int param4, double param5, double param6, int param7, int param8, long param9, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9); }
    public static void callPV(int param0, float param1, float param2, int param3, int param4, float param5, float param6, int param7, int param8, long param9, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9); }
    public static void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, long param9, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9); }
    public static void callJV(long param0, int param1, float param2, float param3, float param4, float param5, float param6, float param7, float param8, float param9, float param10, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10); }
    public static void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, long param10, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10); }
    public static void callPV(long param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10); }
    public static void callJV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, long param10, boolean param11, long __functionAddress) { jni.callJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11); }
    public static void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, long param11, long __functionAddress) { jni.callPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11); }
    public static void callPJV(long param0, long param1, long __functionAddress) { jni.callPJV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callPPV(long param0, long param1, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callSSV(short param0, short param1, long __functionAddress) { jni.callSSV(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static void callJJV(int param0, long param1, long param2, long __functionAddress) { jni.callJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPCV(long param0, int param1, short param2, long __functionAddress) { jni.callPCV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPJV(long param0, int param1, long param2, long __functionAddress) { jni.callPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPJV(long param0, long param1, float param2, long __functionAddress) { jni.callPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPJV(long param0, long param1, int param2, long __functionAddress) { jni.callPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPPV(int param0, long param1, long param2, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPPV(long param0, int param1, long param2, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPPV(long param0, long param1, int param2, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callSSV(int param0, short param1, short param2, long __functionAddress) { jni.callSSV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callJJV(int param0, int param1, long param2, long param3, long __functionAddress) { jni.callJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callJPV(int param0, int param1, long param2, long param3, long __functionAddress) { jni.callJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callJPV(int param0, long param1, int param2, long param3, long __functionAddress) { jni.callJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPJV(int param0, long param1, int param2, long param3, long __functionAddress) { jni.callPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPJV(long param0, int param1, long param2, int param3, long __functionAddress) { jni.callPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPJV(long param0, long param1, int param2, int param3, long __functionAddress) { jni.callPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPV(int param0, int param1, long param2, long param3, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPV(int param0, long param1, int param2, long param3, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPV(int param0, long param1, long param2, int param3, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPV(int param0, long param1, long param2, boolean param3, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPV(long param0, int param1, int param2, long param3, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPV(long param0, long param1, int param2, int param3, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPJV(long param0, long param1, int param2, int param3, int param4, long __functionAddress) { jni.callPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPV(int param0, int param1, int param2, long param3, long param4, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPV(int param0, int param1, long param2, int param3, long param4, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPV(int param0, int param1, long param2, long param3, int param4, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPV(int param0, long param1, int param2, long param3, int param4, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPV(int param0, long param1, long param2, int param3, int param4, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPV(long param0, int param1, int param2, int param3, long param4, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPV(int param0, int param1, int param2, int param3, long param4, long param5, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPV(int param0, int param1, long param2, int param3, int param4, long param5, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPV(int param0, int param1, long param2, long param3, int param4, int param5, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPV(int param0, long param1, long param2, int param3, int param4, int param5, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPV(long param0, int param1, long param2, int param3, int param4, int param5, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPV(int param0, int param1, int param2, int param3, int param4, long param5, long param6, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPV(int param0, int param1, int param2, long param3, int param4, int param5, long param6, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPV(int param0, int param1, long param2, int param3, int param4, int param5, long param6, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPV(int param0, int param1, long param2, long param3, int param4, int param5, int param6, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPV(int param0, int param1, int param2, int param3, int param4, int param5, long param6, long param7, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPPV(int param0, int param1, int param2, int param3, long param4, int param5, int param6, long param7, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPPV(int param0, int param1, long param2, int param3, int param4, int param5, int param6, long param7, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPPV(int param0, int param1, int param2, long param3, int param4, float param5, float param6, int param7, long param8, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static void callPPV(int param0, int param1, long param2, int param3, int param4, int param5, int param6, int param7, long param8, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static void callPPV(int param0, int param1, long param2, int param3, int param4, int param5, long param6, int param7, int param8, float param9, long __functionAddress) { jni.callPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9); }
    public static void callBBBV(byte param0, byte param1, byte param2, long __functionAddress) { jni.callBBBV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callCCCV(short param0, short param1, short param2, long __functionAddress) { jni.callCCCV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPJJV(long param0, long param1, long param2, long __functionAddress) { jni.callPJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPJPV(long param0, long param1, long param2, long __functionAddress) { jni.callPJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPPNV(long param0, long param1, long param2, long __functionAddress) { jni.callPPNV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callPPPV(long param0, long param1, long param2, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callSSSV(short param0, short param1, short param2, long __functionAddress) { jni.callSSSV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callUUUV(byte param0, byte param1, byte param2, long __functionAddress) { jni.callUUUV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static void callJJJV(int param0, long param1, long param2, long param3, long __functionAddress) { jni.callJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPJJV(long param0, long param1, long param2, int param3, long __functionAddress) { jni.callPJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPJPV(long param0, long param1, int param2, long param3, long __functionAddress) { jni.callPJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPPV(int param0, long param1, long param2, long param3, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPPV(long param0, int param1, long param2, long param3, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPPV(long param0, long param1, int param2, long param3, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callSSSV(int param0, short param1, short param2, short param3, long __functionAddress) { jni.callSSSV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callJJJV(int param0, int param1, long param2, long param3, long param4, long __functionAddress) { jni.callJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPJJV(long param0, int param1, long param2, long param3, int param4, long __functionAddress) { jni.callPJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPJJV(long param0, long param1, long param2, int param3, int param4, long __functionAddress) { jni.callPJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPPV(int param0, int param1, long param2, long param3, long param4, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPPV(int param0, long param1, int param2, long param3, long param4, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPPV(int param0, long param1, long param2, int param3, long param4, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPPV(int param0, long param1, long param2, long param3, int param4, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPPV(long param0, int param1, int param2, long param3, long param4, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPPV(long param0, int param1, long param2, int param3, long param4, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPJPV(long param0, int param1, long param2, int param3, int param4, long param5, long __functionAddress) { jni.callPJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPJPV(long param0, long param1, int param2, int param3, int param4, long param5, long __functionAddress) { jni.callPJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPJV(int param0, long param1, long param2, int param3, long param4, boolean param5, long __functionAddress) { jni.callPPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPJV(long param0, int param1, long param2, int param3, long param4, int param5, long __functionAddress) { jni.callPPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPPV(int param0, int param1, int param2, long param3, long param4, long param5, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPPV(int param0, int param1, long param2, int param3, long param4, long param5, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPPV(int param0, long param1, int param2, long param3, int param4, long param5, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPJJV(long param0, int param1, int param2, long param3, long param4, int param5, int param6, long __functionAddress) { jni.callPJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPPV(int param0, int param1, int param2, int param3, long param4, long param5, long param6, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPPV(int param0, int param1, long param2, long param3, int param4, int param5, long param6, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPPV(long param0, int param1, long param2, int param3, int param4, int param5, long param6, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPPV(int param0, int param1, int param2, int param3, long param4, int param5, long param6, long param7, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPPPV(long param0, int param1, int param2, int param3, int param4, int param5, long param6, long param7, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPPPV(long param0, long param1, int param2, int param3, int param4, int param5, int param6, int param7, long param8, int param9, int param10, int param11, int param12, int param13, int param14, int param15, int param16, int param17, long __functionAddress) { jni.callPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16, param17); }
    public static void callBBBBV(byte param0, byte param1, byte param2, byte param3, long __functionAddress) { jni.callBBBBV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callCCCCV(short param0, short param1, short param2, short param3, long __functionAddress) { jni.callCCCCV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPJJJV(long param0, long param1, long param2, long param3, long __functionAddress) { jni.callPJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPJJPV(long param0, long param1, long param2, long param3, long __functionAddress) { jni.callPJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPJPPV(long param0, long param1, long param2, long param3, long __functionAddress) { jni.callPJPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPPNV(long param0, long param1, long param2, long param3, long __functionAddress) { jni.callPPPNV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callPPPPV(long param0, long param1, long param2, long param3, long __functionAddress) { jni.callPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callSSSSV(short param0, short param1, short param2, short param3, long __functionAddress) { jni.callSSSSV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callUUUUV(byte param0, byte param1, byte param2, byte param3, long __functionAddress) { jni.callUUUUV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static void callJJJJV(int param0, long param1, long param2, long param3, long param4, long __functionAddress) { jni.callJJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPJJJV(long param0, long param1, long param2, long param3, int param4, long __functionAddress) { jni.callPJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPJJPV(long param0, int param1, long param2, long param3, long param4, long __functionAddress) { jni.callPJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPJJPV(long param0, long param1, long param2, int param3, long param4, long __functionAddress) { jni.callPJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPPPV(long param0, int param1, long param2, long param3, long param4, long __functionAddress) { jni.callPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPPPV(long param0, long param1, long param2, long param3, int param4, long __functionAddress) { jni.callPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callSSSSV(int param0, short param1, short param2, short param3, short param4, long __functionAddress) { jni.callSSSSV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callUUUUV(int param0, byte param1, byte param2, byte param3, byte param4, long __functionAddress) { jni.callUUUUV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callJJJJV(int param0, int param1, long param2, long param3, long param4, long param5, long __functionAddress) { jni.callJJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPJJJV(long param0, long param1, long param2, long param3, int param4, int param5, long __functionAddress) { jni.callPJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPJJPV(long param0, long param1, int param2, long param3, int param4, long param5, long __functionAddress) { jni.callPJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPJJPV(long param0, long param1, long param2, int param3, int param4, long param5, long __functionAddress) { jni.callPJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPJPPV(long param0, long param1, int param2, long param3, int param4, long param5, long __functionAddress) { jni.callPJPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPPPV(int param0, long param1, long param2, long param3, long param4, int param5, long __functionAddress) { jni.callPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPPPV(long param0, int param1, int param2, long param3, long param4, long param5, long __functionAddress) { jni.callPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPJJPV(long param0, long param1, int param2, int param3, long param4, int param5, long param6, long __functionAddress) { jni.callPJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPJJPV(long param0, long param1, int param2, long param3, int param4, int param5, long param6, long __functionAddress) { jni.callPJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPJPPV(long param0, int param1, long param2, int param3, int param4, long param5, long param6, long __functionAddress) { jni.callPJPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPPPV(int param0, int param1, int param2, long param3, long param4, long param5, long param6, long __functionAddress) { jni.callPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPPPV(int param0, int param1, long param2, long param3, long param4, long param5, int param6, long __functionAddress) { jni.callPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPJJPV(long param0, long param1, int param2, long param3, int param4, int param5, long param6, int param7, long __functionAddress) { jni.callPJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPJPPV(long param0, int param1, long param2, int param3, int param4, long param5, int param6, long param7, long __functionAddress) { jni.callPJPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPPPPV(long param0, int param1, int param2, int param3, int param4, long param5, int param6, long param7, int param8, long param9, long __functionAddress) { jni.callPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9); }
    public static void callPJJJPV(long param0, long param1, long param2, long param3, long param4, long __functionAddress) { jni.callPJJJPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4); }
    public static void callPPPPPV(long param0, int param1, long param2, long param3, long param4, long param5, long __functionAddress) { jni.callPPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPJJJJV(long param0, long param1, long param2, long param3, long param4, int param5, int param6, long __functionAddress) { jni.callPJJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPPPPV(int param0, int param1, long param2, long param3, long param4, long param5, long param6, long __functionAddress) { jni.callPPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPPPPPV(long param0, int param1, int param2, long param3, long param4, long param5, long param6, long __functionAddress) { jni.callPPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6); }
    public static void callPJJJJV(long param0, long param1, int param2, int param3, long param4, long param5, long param6, int param7, long __functionAddress) { jni.callPJJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPJPPPV(long param0, int param1, int param2, long param3, long param4, int param5, long param6, long param7, long __functionAddress) { jni.callPJPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPPPPPV(long param0, long param1, long param2, long param3, long param4, int param5, int param6, int param7, long __functionAddress) { jni.callPPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPPPPPV(long param0, int param1, long param2, int param3, int param4, int param5, long param6, int param7, long param8, int param9, long param10, long __functionAddress) { jni.callPPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10); }
    public static void callPPPPPJV(long param0, long param1, long param2, long param3, long param4, long param5, long __functionAddress) { jni.callPPPPPJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5); }
    public static void callPPPPPPV(long param0, long param1, long param2, int param3, int param4, long param5, long param6, long param7, long __functionAddress) { jni.callPPPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }
    public static void callPPPPPPPV(int param0, int param1, int param2, long param3, int param4, long param5, long param6, long param7, long param8, long param9, long param10, long __functionAddress) { jni.callPPPPPPPV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10); }
    public static void callPPJJJJJJV(long param0, long param1, long param2, long param3, int param4, long param5, long param6, long param7, long param8, long __functionAddress) { jni.callPPJJJJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8); }
    public static void callPJJJJJJJJJJJV(long param0, long param1, long param2, long param3, long param4, long param5, long param6, long param7, long param8, long param9, long param10, long param11, int param12, int param13, int param14, long __functionAddress) { jni.callPJJJJJJJJJJJV(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14); }
    public static boolean callZ(int param0, long __functionAddress) { return jni.callZ(MemorySegment.ofAddress(__functionAddress), param0); }
    public static boolean callZ(int param0, int param1, long __functionAddress) { return jni.callZ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static boolean callZ(int param0, float param1, float param2, long __functionAddress) { return jni.callZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static boolean callZ(int param0, int param1, float param2, float param3, long __functionAddress) { return jni.callZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3); }
    public static boolean callJZ(long param0, long __functionAddress) { return jni.callJZ(MemorySegment.ofAddress(__functionAddress), param0); }
    public static boolean callPZ(long param0, long __functionAddress) { return jni.callPZ(MemorySegment.ofAddress(__functionAddress), param0); }
    public static boolean callJZ(int param0, long param1, long __functionAddress) { return jni.callJZ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static boolean callPZ(int param0, long param1, long __functionAddress) { return jni.callPZ(MemorySegment.ofAddress(__functionAddress), param0, param1); }
    public static boolean callJZ(int param0, long param1, int param2, long __functionAddress) { return jni.callJZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static boolean callPPZ(int param0, long param1, long param2, long __functionAddress) { return jni.callPPZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2); }
    public static boolean callPPPPZ(int param0, int param1, int param2, float param3, long param4, long param5, long param6, long param7, long __functionAddress) { return jni.callPPPPZ(MemorySegment.ofAddress(__functionAddress), param0, param1, param2, param3, param4, param5, param6, param7); }

    // Array API

    public static native int invokePPI(int param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native int invokePPPPI(long param0, long param1, long param2, long @Nullable [] param3, long __functionAddress);
    public static native int invokePPPPPI(long param0, int @Nullable [] param1, int @Nullable [] param2, int @Nullable [] param3, long param4, long __functionAddress);
    public static native int invokePNNPPPI(long param0, long param1, long param2, int param3, int param4, int @Nullable [] param5, int @Nullable [] param6, long param7, long __functionAddress);
    public static native int invokePPPPPPI(int param0, int param1, int @Nullable [] param2, int @Nullable [] param3, int @Nullable [] param4, int @Nullable [] param5, int @Nullable [] param6, long param7, long __functionAddress);
    public static native int invokePPPPPPPI(long param0, int param1, int param2, int @Nullable [] param3, int @Nullable [] param4, int @Nullable [] param5, int @Nullable [] param6, int @Nullable [] param7, long param8, long __functionAddress);
    public static native long invokePPP(long param0, int @Nullable [] param1, long __functionAddress);
    public static native void invokePV(int param0, double @Nullable [] param1, long __functionAddress);
    public static native void invokePV(int param0, float @Nullable [] param1, long __functionAddress);
    public static native void invokePV(int param0, int @Nullable [] param1, long __functionAddress);
    public static native void invokePV(int param0, int param1, double @Nullable [] param2, long __functionAddress);
    public static native void invokePV(int param0, int param1, float @Nullable [] param2, long __functionAddress);
    public static native void invokePV(int param0, int param1, int @Nullable [] param2, long __functionAddress);
    public static native void invokePV(int param0, int param1, long @Nullable [] param2, long __functionAddress);
    public static native void invokePV(int param0, int @Nullable [] param1, boolean param2, long __functionAddress);
    public static native void invokePV(int param0, int param1, float @Nullable [] param2, int param3, int param4, long __functionAddress);
    public static native void invokePV(int param0, int param1, int @Nullable [] param2, int param3, int param4, long __functionAddress);
    public static native void invokePV(int param0, int param1, short @Nullable [] param2, int param3, int param4, long __functionAddress);
    public static native void invokePV(int param0, int param1, int param2, int param3, int param4, double @Nullable [] param5, long __functionAddress);
    public static native void invokePV(int param0, int param1, int param2, int param3, int param4, float @Nullable [] param5, long __functionAddress);
    public static native void invokePV(int param0, int param1, int param2, int param3, int param4, int @Nullable [] param5, long __functionAddress);
    public static native void invokePV(int param0, int param1, int param2, int param3, int param4, short @Nullable [] param5, long __functionAddress);
    public static native void invokePV(int param0, int param1, int param2, int param3, int @Nullable [] param4, boolean param5, long __functionAddress);
    public static native void invokePV(int param0, int param1, int param2, int param3, int param4, int param5, double @Nullable [] param6, long __functionAddress);
    public static native void invokePV(int param0, int param1, int param2, int param3, int param4, int param5, float @Nullable [] param6, long __functionAddress);
    public static native void invokePV(int param0, int param1, int param2, int param3, int param4, int param5, int @Nullable [] param6, long __functionAddress);
    public static native void invokePV(int param0, int param1, int param2, int param3, int param4, int param5, short @Nullable [] param6, long __functionAddress);
    public static native void invokePJV(int param0, int @Nullable [] param1, long param2, long __functionAddress);
    public static native void invokePPV(long param0, int param1, double @Nullable [] param2, long __functionAddress);
    public static native void invokePPV(long param0, int param1, float @Nullable [] param2, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int @Nullable [] param2, long __functionAddress);
    public static native void invokePPV(long param0, float @Nullable [] param1, int param2, long __functionAddress);
    public static native void invokePPV(long param0, int @Nullable [] param1, int param2, long __functionAddress);
    public static native void invokePPV(long param0, short @Nullable [] param1, int param2, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int param2, double @Nullable [] param3, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int param2, float @Nullable [] param3, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int param2, int @Nullable [] param3, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int param2, long @Nullable [] param3, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int @Nullable [] param2, boolean param3, long __functionAddress);
    public static native void invokePPV(int param0, int param1, int param2, int @Nullable [] param3, long param4, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int param2, float @Nullable [] param3, int param4, int param5, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int param2, int @Nullable [] param3, int param4, int param5, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int param2, short @Nullable [] param3, int param4, int param5, long __functionAddress);
    public static native void invokePPV(long param0, int param1, int param2, int param3, int param4, int @Nullable [] param5, boolean param6, long __functionAddress);
    public static native void invokePNPV(long param0, long param1, short @Nullable [] param2, long __functionAddress);
    public static native void invokePPPV(long param0, double @Nullable [] param1, double @Nullable [] param2, long __functionAddress);
    public static native void invokePPPV(long param0, float @Nullable [] param1, float @Nullable [] param2, long __functionAddress);
    public static native void invokePPPV(long param0, int @Nullable [] param1, int @Nullable [] param2, long __functionAddress);
    public static native void invokePPPV(int @Nullable [] param0, int @Nullable [] param1, int @Nullable [] param2, long __functionAddress);
    public static native void invokePPJV(long param0, int param1, int @Nullable [] param2, long param3, long __functionAddress);
    public static native void invokePPPV(int param0, float @Nullable [] param1, float @Nullable [] param2, float @Nullable [] param3, long __functionAddress);
    public static native void invokePPPV(int param0, int @Nullable [] param1, int @Nullable [] param2, int @Nullable [] param3, long __functionAddress);
    public static native void invokePPPV(int param0, int param1, double @Nullable [] param2, double @Nullable [] param3, double @Nullable [] param4, long __functionAddress);
    public static native void invokePPPV(int param0, int param1, float @Nullable [] param2, float @Nullable [] param3, float @Nullable [] param4, long __functionAddress);
    public static native void invokePPPV(int param0, int param1, int @Nullable [] param2, int @Nullable [] param3, int @Nullable [] param4, long __functionAddress);
    public static native void invokePPPV(int param0, int param1, long @Nullable [] param2, long @Nullable [] param3, long @Nullable [] param4, long __functionAddress);
    public static native void invokePPPV(long param0, int param1, int param2, int param3, int @Nullable [] param4, long param5, long __functionAddress);
    public static native void invokePNPPV(long param0, long param1, long param2, short @Nullable [] param3, long __functionAddress);
    public static native void invokePPPPV(long param0, int param1, float @Nullable [] param2, float @Nullable [] param3, float @Nullable [] param4, long __functionAddress);
    public static native void invokePPPPV(long param0, int param1, int @Nullable [] param2, int @Nullable [] param3, int @Nullable [] param4, long __functionAddress);
    public static native void invokePPPPV(long param0, int param1, int param2, double @Nullable [] param3, double @Nullable [] param4, double @Nullable [] param5, long __functionAddress);
    public static native void invokePPPPV(long param0, int param1, int param2, float @Nullable [] param3, float @Nullable [] param4, float @Nullable [] param5, long __functionAddress);
    public static native void invokePPPPV(long param0, int param1, int param2, int @Nullable [] param3, int @Nullable [] param4, int @Nullable [] param5, long __functionAddress);
    public static native void invokePPPPV(long param0, int param1, int param2, long @Nullable [] param3, long @Nullable [] param4, long @Nullable [] param5, long __functionAddress);
    public static native void invokePPPPPV(long param0, int @Nullable [] param1, int @Nullable [] param2, int @Nullable [] param3, int @Nullable [] param4, long __functionAddress);
    public static native boolean invokePZ(int param0, int @Nullable [] param1, boolean param2, long __functionAddress);
    public static native boolean invokePPZ(long param0, int @Nullable [] param1, long __functionAddress);
    public static native boolean invokePPPZ(long param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native int callPI(int @Nullable [] param0, long __functionAddress);
    public static native int callPI(int param0, int @Nullable [] param1, long __functionAddress);
    public static native int callPI(int param0, int param1, int @Nullable [] param2, long __functionAddress);
    public static native int callPI(int param0, int param1, int param2, int @Nullable [] param3, long __functionAddress);
    public static native int callPI(int param0, int param1, int param2, int param3, float @Nullable [] param4, long __functionAddress);
    public static native int callPI(int param0, int param1, int param2, int param3, int @Nullable [] param4, long __functionAddress);
    public static native int callPPI(long param0, int @Nullable [] param1, long __functionAddress);
    public static native int callPPI(int @Nullable [] param0, long param1, long __functionAddress);
    public static native int callPPI(int param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native int callPPI(long param0, int param1, int @Nullable [] param2, long __functionAddress);
    public static native int callPPI(long param0, int param1, long @Nullable [] param2, long __functionAddress);
    public static native int callPPI(long param0, int param1, int param2, int @Nullable [] param3, long __functionAddress);
    public static native int callPPI(long param0, int param1, int param2, long @Nullable [] param3, long __functionAddress);
    public static native int callPPI(int param0, long param1, int param2, int param3, float param4, int @Nullable [] param5, long __functionAddress);
    public static native int callPJPI(long param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native int callPJPI(long param0, long param1, long @Nullable [] param2, long __functionAddress);
    public static native int callPPPI(long param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native int callPPPI(long param0, long param1, long @Nullable [] param2, long __functionAddress);
    public static native int callPPPI(long param0, int @Nullable [] param1, long param2, long __functionAddress);
    public static native int callPPPI(long param0, int @Nullable [] param1, int @Nullable [] param2, long __functionAddress);
    public static native int callPPPI(int @Nullable [] param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native int callPJPI(long param0, int param1, long param2, int @Nullable [] param3, long __functionAddress);
    public static native int callPJPI(long param0, long param1, int param2, long @Nullable [] param3, long __functionAddress);
    public static native int callPPPI(long param0, int param1, int @Nullable [] param2, long param3, long __functionAddress);
    public static native int callPPPI(long param0, int param1, int @Nullable [] param2, int @Nullable [] param3, long __functionAddress);
    public static native int callPPPI(long param0, int param1, int @Nullable [] param2, long @Nullable [] param3, long __functionAddress);
    public static native int callPPPI(long param0, int param1, long @Nullable [] param2, long param3, long __functionAddress);
    public static native int callPPPI(long param0, long param1, int param2, int @Nullable [] param3, long __functionAddress);
    public static native int callPPJI(long param0, int param1, long @Nullable [] param2, int param3, long param4, long __functionAddress);
    public static native int callPPPI(long param0, int param1, int param2, int param3, int @Nullable [] param4, float @Nullable [] param5, long __functionAddress);
    public static native int callPPPI(long param0, int param1, int param2, int param3, int @Nullable [] param4, int @Nullable [] param5, long __functionAddress);
    public static native int callPJPPI(long param0, long param1, long param2, int @Nullable [] param3, long __functionAddress);
    public static native int callPJPPI(long param0, long param1, long param2, long @Nullable [] param3, long __functionAddress);
    public static native int callPJPPI(long param0, long param1, int @Nullable [] param2, long param3, long __functionAddress);
    public static native int callPJPPI(long param0, long param1, int @Nullable [] param2, int @Nullable [] param3, long __functionAddress);
    public static native int callPJPPI(long param0, long param1, int @Nullable [] param2, long @Nullable [] param3, long __functionAddress);
    public static native int callPPNPI(long param0, long param1, long param2, long @Nullable [] param3, long __functionAddress);
    public static native int callPPPPI(long param0, long param1, long param2, long @Nullable [] param3, long __functionAddress);
    public static native int callPPPPI(long param0, long param1, int @Nullable [] param2, long param3, long __functionAddress);
    public static native int callPPPPI(long param0, long param1, int @Nullable [] param2, int @Nullable [] param3, long __functionAddress);
    public static native int callPPPPI(long param0, int param1, long param2, long param3, long @Nullable [] param4, long __functionAddress);
    public static native int callPPPPI(long param0, int param1, long param2, long @Nullable [] param3, long @Nullable [] param4, long __functionAddress);
    public static native int callPPPPI(long param0, int param1, int @Nullable [] param2, long param3, long param4, long __functionAddress);
    public static native int callPPPPI(int param0, int @Nullable [] param1, long @Nullable [] param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int param11, int param12, int param13, int param14, int param15, int param16, int param17, int param18, int param19, int param20, int @Nullable [] param21, long @Nullable [] param22, long __functionAddress);
    public static native int callPJPPPI(long param0, long param1, long param2, long param3, long @Nullable [] param4, long __functionAddress);
    public static native int callPPPPPI(long param0, long param1, int @Nullable [] param2, int @Nullable [] param3, int @Nullable [] param4, long __functionAddress);
    public static native int callPPPPPI(long param0, int @Nullable [] param1, int @Nullable [] param2, int @Nullable [] param3, long param4, long __functionAddress);
    public static native int callPJPPPI(long param0, long param1, int param2, long param3, long param4, long @Nullable [] param5, long __functionAddress);
    public static native int callPPPPPI(long param0, int @Nullable [] param1, float @Nullable [] param2, int param3, int @Nullable [] param4, int @Nullable [] param5, long __functionAddress);
    public static native int callPPPPPI(int param0, int param1, int @Nullable [] param2, int @Nullable [] param3, int @Nullable [] param4, int @Nullable [] param5, long param6, long __functionAddress);
    public static native int callPPPPPI(long param0, int param1, long @Nullable [] param2, int param3, long param4, long param5, long param6, long __functionAddress);
    public static native int callPJPPJI(long param0, long param1, int param2, int param3, long param4, int @Nullable [] param5, long param6, int param7, long __functionAddress);
    public static native int callPJPPJI(long param0, long param1, int param2, int param3, long param4, long @Nullable [] param5, long param6, int param7, long __functionAddress);
    public static native int callPJJJJPI(long param0, long param1, long param2, long param3, long param4, int @Nullable [] param5, long __functionAddress);
    public static native int callPPPPPPI(long param0, int @Nullable [] param1, int @Nullable [] param2, int @Nullable [] param3, int @Nullable [] param4, int @Nullable [] param5, long __functionAddress);
    public static native int callPJJPPPI(long param0, long param1, long param2, int param3, long param4, long param5, long @Nullable [] param6, long __functionAddress);
    public static native int callPPPPPPI(int param0, int param1, int @Nullable [] param2, int @Nullable [] param3, int @Nullable [] param4, int @Nullable [] param5, int @Nullable [] param6, long param7, long __functionAddress);
    public static native long callPPP(int param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native long callPPP(long param0, int param1, int @Nullable [] param2, long __functionAddress);
    public static native long callPPP(int param0, int param1, int param2, int @Nullable [] param3, int @Nullable [] param4, long __functionAddress);
    public static native long callPPP(long param0, int param1, int param2, int param3, int @Nullable [] param4, long __functionAddress);
    public static native long callPPPP(long param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native long callPPPP(long param0, int param1, int @Nullable [] param2, long param3, long __functionAddress);
    public static native long callPPPP(long param0, long param1, int param2, int param3, int @Nullable [] param4, long __functionAddress);
    public static native long callPPNPP(long param0, long param1, long param2, int @Nullable [] param3, long __functionAddress);
    public static native long callPPPPP(long param0, long param1, long param2, int param3, int @Nullable [] param4, long __functionAddress);
    public static native long callPPPPPPPP(int param0, int @Nullable [] param1, long @Nullable [] param2, int param3, int param4, int param5, int param6, long param7, long param8, long param9, int param10, int @Nullable [] param11, long @Nullable [] param12, long __functionAddress);
    public static native void callPV(double @Nullable [] param0, long __functionAddress);
    public static native void callPV(float @Nullable [] param0, long __functionAddress);
    public static native void callPV(int @Nullable [] param0, long __functionAddress);
    public static native void callPV(short @Nullable [] param0, long __functionAddress);
    public static native void callPV(int param0, double @Nullable [] param1, long __functionAddress);
    public static native void callPV(int param0, float @Nullable [] param1, long __functionAddress);
    public static native void callPV(int param0, int @Nullable [] param1, long __functionAddress);
    public static native void callPV(int param0, long @Nullable [] param1, long __functionAddress);
    public static native void callPV(int param0, short @Nullable [] param1, long __functionAddress);
    public static native void callPV(int param0, int param1, double @Nullable [] param2, long __functionAddress);
    public static native void callPV(int param0, int param1, float @Nullable [] param2, long __functionAddress);
    public static native void callPV(int param0, int param1, int @Nullable [] param2, long __functionAddress);
    public static native void callPV(int param0, int param1, long @Nullable [] param2, long __functionAddress);
    public static native void callPV(int param0, int param1, short @Nullable [] param2, long __functionAddress);
    public static native void callPV(int param0, int @Nullable [] param1, int param2, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, double @Nullable [] param3, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, float @Nullable [] param3, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int @Nullable [] param3, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, long @Nullable [] param3, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, short @Nullable [] param3, long __functionAddress);
    public static native void callPV(int param0, int param1, boolean param2, double @Nullable [] param3, long __functionAddress);
    public static native void callPV(int param0, int param1, boolean param2, float @Nullable [] param3, long __functionAddress);
    public static native void callPV(int param0, int param1, boolean param2, int @Nullable [] param3, long __functionAddress);
    public static native void callPV(int param0, int param1, int @Nullable [] param2, int param3, long __functionAddress);
    public static native void callPV(int param0, int @Nullable [] param1, int param2, int param3, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, double @Nullable [] param4, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, float @Nullable [] param4, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, long @Nullable [] param4, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, short @Nullable [] param4, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, boolean param3, double @Nullable [] param4, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, boolean param3, float @Nullable [] param4, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int @Nullable [] param3, boolean param4, long __functionAddress);
    public static native void callPV(int param0, int param1, int @Nullable [] param2, int param3, int param4, long __functionAddress);
    public static native void callPV(int param0, boolean param1, int param2, int param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPV(int param0, double param1, double param2, int param3, int param4, double @Nullable [] param5, long __functionAddress);
    public static native void callPV(int param0, float param1, float param2, int param3, int param4, float @Nullable [] param5, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, double @Nullable [] param5, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, float @Nullable [] param5, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int @Nullable [] param5, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, short @Nullable [] param5, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int @Nullable [] param4, boolean param5, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, boolean param3, int param4, float @Nullable [] param5, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, boolean param3, int param4, int @Nullable [] param5, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, boolean param3, int param4, short @Nullable [] param5, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, double @Nullable [] param6, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, float @Nullable [] param6, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int @Nullable [] param6, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, short @Nullable [] param6, long __functionAddress);
    public static native void callPV(int param0, int param1, int @Nullable [] param2, int param3, int param4, int param5, int param6, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, double @Nullable [] param7, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, float @Nullable [] param7, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int @Nullable [] param7, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, short @Nullable [] param7, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, double @Nullable [] param8, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, float @Nullable [] param8, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int @Nullable [] param8, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, short @Nullable [] param8, long __functionAddress);
    public static native void callPV(int param0, double param1, double param2, int param3, int param4, double param5, double param6, int param7, int param8, double @Nullable [] param9, long __functionAddress);
    public static native void callPV(int param0, float param1, float param2, int param3, int param4, float param5, float param6, int param7, int param8, float @Nullable [] param9, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, double @Nullable [] param9, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, float @Nullable [] param9, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int @Nullable [] param9, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, short @Nullable [] param9, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, double @Nullable [] param10, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, float @Nullable [] param10, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int @Nullable [] param10, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, short @Nullable [] param10, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, double @Nullable [] param11, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, float @Nullable [] param11, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, int @Nullable [] param11, long __functionAddress);
    public static native void callPV(int param0, int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8, int param9, int param10, short @Nullable [] param11, long __functionAddress);
    public static native void callPPV(long param0, float @Nullable [] param1, long __functionAddress);
    public static native void callPPV(long param0, int @Nullable [] param1, long __functionAddress);
    public static native void callPPV(double @Nullable [] param0, double @Nullable [] param1, long __functionAddress);
    public static native void callPPV(float @Nullable [] param0, float @Nullable [] param1, long __functionAddress);
    public static native void callPPV(int @Nullable [] param0, int @Nullable [] param1, long __functionAddress);
    public static native void callPPV(short @Nullable [] param0, short @Nullable [] param1, long __functionAddress);
    public static native void callPPV(int param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native void callPPV(int param0, int @Nullable [] param1, float @Nullable [] param2, long __functionAddress);
    public static native void callPPV(int param0, int @Nullable [] param1, long @Nullable [] param2, long __functionAddress);
    public static native void callPPV(long param0, int param1, float @Nullable [] param2, long __functionAddress);
    public static native void callPPV(long param0, int param1, int @Nullable [] param2, long __functionAddress);
    public static native void callPPV(int @Nullable [] param0, int param1, int @Nullable [] param2, long __functionAddress);
    public static native void callPPV(int param0, int param1, long param2, int @Nullable [] param3, long __functionAddress);
    public static native void callPPV(int param0, int param1, int @Nullable [] param2, long param3, long __functionAddress);
    public static native void callPPV(int param0, int param1, int @Nullable [] param2, float @Nullable [] param3, long __functionAddress);
    public static native void callPPV(int param0, int param1, int @Nullable [] param2, int @Nullable [] param3, long __functionAddress);
    public static native void callPPV(int param0, int param1, int @Nullable [] param2, long @Nullable [] param3, long __functionAddress);
    public static native void callPPV(int param0, long param1, int param2, int @Nullable [] param3, long __functionAddress);
    public static native void callPPV(int param0, long param1, double @Nullable [] param2, int param3, long __functionAddress);
    public static native void callPPV(int param0, long param1, float @Nullable [] param2, int param3, long __functionAddress);
    public static native void callPPV(int param0, long param1, int @Nullable [] param2, int param3, long __functionAddress);
    public static native void callPPV(int param0, long param1, long @Nullable [] param2, int param3, long __functionAddress);
    public static native void callPPV(int param0, long param1, short @Nullable [] param2, int param3, long __functionAddress);
    public static native void callPPV(int param0, int @Nullable [] param1, int @Nullable [] param2, int param3, long __functionAddress);
    public static native void callPPV(int param0, long @Nullable [] param1, int @Nullable [] param2, int param3, long __functionAddress);
    public static native void callPPV(long param0, int param1, int param2, int @Nullable [] param3, long __functionAddress);
    public static native void callPPV(int param0, int param1, int param2, long param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPPV(int param0, int param1, int param2, int @Nullable [] param3, long param4, long __functionAddress);
    public static native void callPPV(int param0, int param1, int param2, int @Nullable [] param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPPV(int param0, int param1, long param2, int @Nullable [] param3, int param4, long __functionAddress);
    public static native void callPPV(int param0, int param1, int @Nullable [] param2, int param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPPV(int param0, int @Nullable [] param1, int param2, long param3, int param4, long __functionAddress);
    public static native void callPPV(int param0, int @Nullable [] param1, int param2, int @Nullable [] param3, int param4, long __functionAddress);
    public static native void callPPV(int param0, int @Nullable [] param1, long param2, int param3, int param4, long __functionAddress);
    public static native void callPPV(long param0, int param1, int param2, int param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPPV(int param0, int param1, int param2, int param3, int @Nullable [] param4, long param5, long __functionAddress);
    public static native void callPPV(int param0, int param1, long param2, int param3, int param4, float @Nullable [] param5, long __functionAddress);
    public static native void callPPV(int param0, int param1, long param2, int param3, int param4, short @Nullable [] param5, long __functionAddress);
    public static native void callPPV(int param0, int param1, int @Nullable [] param2, long param3, int param4, int param5, long __functionAddress);
    public static native void callPPV(int param0, int param1, int param2, long param3, int param4, int param5, float @Nullable [] param6, long __functionAddress);
    public static native void callPPV(int param0, int param1, long param2, int param3, int param4, int param5, float @Nullable [] param6, long __functionAddress);
    public static native void callPPV(int param0, int param1, int param2, int param3, long param4, int param5, int param6, float @Nullable [] param7, long __functionAddress);
    public static native void callPPV(int param0, int param1, int param2, int param3, long param4, int param5, int param6, short @Nullable [] param7, long __functionAddress);
    public static native void callPPV(int param0, int param1, long param2, int param3, int param4, int param5, int param6, float @Nullable [] param7, long __functionAddress);
    public static native void callPPV(int param0, int param1, int param2, long param3, int param4, float param5, float param6, int param7, float @Nullable [] param8, long __functionAddress);
    public static native void callPPV(int param0, int param1, long param2, int param3, int param4, int param5, int param6, int param7, float @Nullable [] param8, long __functionAddress);
    public static native void callPJPV(long param0, long param1, long @Nullable [] param2, long __functionAddress);
    public static native void callPPPV(long param0, long param1, int @Nullable [] param2, long __functionAddress);
    public static native void callPPPV(long param0, int @Nullable [] param1, long param2, long __functionAddress);
    public static native void callPJPV(long param0, long param1, int param2, long @Nullable [] param3, long __functionAddress);
    public static native void callPPPV(int param0, long param1, long param2, double @Nullable [] param3, long __functionAddress);
    public static native void callPPPV(int param0, long param1, long param2, float @Nullable [] param3, long __functionAddress);
    public static native void callPPPV(int param0, long param1, long param2, int @Nullable [] param3, long __functionAddress);
    public static native void callPPPV(int param0, long param1, long param2, long @Nullable [] param3, long __functionAddress);
    public static native void callPPPV(int param0, long param1, long param2, short @Nullable [] param3, long __functionAddress);
    public static native void callPPPV(long param0, int param1, int @Nullable [] param2, long param3, long __functionAddress);
    public static native void callPPPV(long param0, int param1, int @Nullable [] param2, long @Nullable [] param3, long __functionAddress);
    public static native void callPPPV(long param0, int param1, long @Nullable [] param2, long param3, long __functionAddress);
    public static native void callPPPV(long param0, long param1, int param2, int @Nullable [] param3, long __functionAddress);
    public static native void callPPPV(int param0, int param1, long param2, long param3, double @Nullable [] param4, long __functionAddress);
    public static native void callPPPV(int param0, int param1, long param2, long param3, float @Nullable [] param4, long __functionAddress);
    public static native void callPPPV(int param0, int param1, long param2, long param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPPPV(int param0, int param1, long param2, long param3, short @Nullable [] param4, long __functionAddress);
    public static native void callPPPV(int param0, int param1, int @Nullable [] param2, long param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPPPV(int param0, int param1, int @Nullable [] param2, int @Nullable [] param3, long param4, long __functionAddress);
    public static native void callPPPV(int param0, long param1, int param2, int @Nullable [] param3, long param4, long __functionAddress);
    public static native void callPPPV(int param0, long param1, int param2, int @Nullable [] param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPPPV(int param0, int @Nullable [] param1, int @Nullable [] param2, int param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPPPV(long param0, int param1, int param2, int @Nullable [] param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPPPV(long param0, int param1, int param2, long @Nullable [] param3, long @Nullable [] param4, long __functionAddress);
    public static native void callPJPV(long param0, long param1, int param2, int param3, int param4, double @Nullable [] param5, long __functionAddress);
    public static native void callPJPV(long param0, long param1, int param2, int param3, int param4, float @Nullable [] param5, long __functionAddress);
    public static native void callPJPV(long param0, long param1, int param2, int param3, int param4, int @Nullable [] param5, long __functionAddress);
    public static native void callPJPV(long param0, long param1, int param2, int param3, int param4, long @Nullable [] param5, long __functionAddress);
    public static native void callPJPV(long param0, long param1, int param2, int param3, int param4, short @Nullable [] param5, long __functionAddress);
    public static native void callPPJV(long param0, int param1, long @Nullable [] param2, int param3, long param4, int param5, long __functionAddress);
    public static native void callPPPV(int param0, int param1, int param2, int @Nullable [] param3, long param4, long param5, long __functionAddress);
    public static native void callPPPV(int param0, int param1, int param2, int @Nullable [] param3, long param4, int @Nullable [] param5, long __functionAddress);
    public static native void callPPPV(int param0, int param1, int @Nullable [] param2, int param3, int @Nullable [] param4, int @Nullable [] param5, long __functionAddress);
    public static native void callPPPV(int param0, int @Nullable [] param1, int param2, long param3, int param4, int @Nullable [] param5, long __functionAddress);
    public static native void callPPPV(int param0, int param1, long param2, long param3, int param4, int param5, float @Nullable [] param6, long __functionAddress);
    public static native void callPPPV(int param0, int param1, long param2, long param3, int param4, int param5, int @Nullable [] param6, long __functionAddress);
    public static native void callPPPV(int param0, int param1, long param2, long param3, int param4, int param5, short @Nullable [] param6, long __functionAddress);
    public static native void callPPPV(long param0, int param1, long param2, int param3, int param4, int param5, int @Nullable [] param6, long __functionAddress);
    public static native void callPPPV(int param0, int param1, int param2, int param3, int @Nullable [] param4, int param5, int @Nullable [] param6, float @Nullable [] param7, long __functionAddress);
    public static native void callPPPV(int param0, int param1, int param2, int param3, int @Nullable [] param4, int param5, int @Nullable [] param6, int @Nullable [] param7, long __functionAddress);
    public static native void callPPPV(long param0, int param1, int param2, int param3, int param4, int param5, int @Nullable [] param6, long param7, long __functionAddress);
    public static native void callPJPPV(long param0, long param1, int @Nullable [] param2, long param3, long __functionAddress);
    public static native void callPPPPV(long param0, long param1, int @Nullable [] param2, long param3, long __functionAddress);
    public static native void callPJJPV(long param0, int param1, long param2, long param3, long @Nullable [] param4, long __functionAddress);
    public static native void callPPPPV(long param0, int param1, long param2, int @Nullable [] param3, long param4, long __functionAddress);
    public static native void callPPPPV(long @Nullable [] param0, int @Nullable [] param1, int @Nullable [] param2, int @Nullable [] param3, int param4, long __functionAddress);
    public static native void callPPPPV(int param0, long param1, int @Nullable [] param2, int @Nullable [] param3, int @Nullable [] param4, int param5, long __functionAddress);
    public static native void callPPPPV(long param0, int param1, int param2, long @Nullable [] param3, long @Nullable [] param4, long @Nullable [] param5, long __functionAddress);
    public static native void callPJPPV(long param0, int param1, long param2, int param3, int param4, int @Nullable [] param5, long @Nullable [] param6, long __functionAddress);
    public static native void callPPPPV(int param0, int param1, int param2, int @Nullable [] param3, int @Nullable [] param4, int @Nullable [] param5, long param6, long __functionAddress);
    public static native void callPPPPV(int param0, int param1, long param2, int @Nullable [] param3, int @Nullable [] param4, int @Nullable [] param5, int param6, long __functionAddress);
    public static native void callPJPPV(long param0, int param1, long param2, int param3, int param4, long @Nullable [] param5, int param6, int @Nullable [] param7, long __functionAddress);
    public static native void callPJJJPV(long param0, long param1, long param2, long param3, double @Nullable [] param4, long __functionAddress);
    public static native void callPJJJPV(long param0, long param1, long param2, long param3, float @Nullable [] param4, long __functionAddress);
    public static native void callPJJJPV(long param0, long param1, long param2, long param3, int @Nullable [] param4, long __functionAddress);
    public static native void callPJJJPV(long param0, long param1, long param2, long param3, long @Nullable [] param4, long __functionAddress);
    public static native void callPJJJPV(long param0, long param1, long param2, long param3, short @Nullable [] param4, long __functionAddress);
    public static native void callPPPPPV(long param0, int param1, long param2, long @Nullable [] param3, int @Nullable [] param4, long param5, long __functionAddress);
    public static native void callPPPPPV(int param0, int param1, long param2, int @Nullable [] param3, int @Nullable [] param4, int @Nullable [] param5, int @Nullable [] param6, long __functionAddress);
    public static native void callPPPPPV(long param0, int param1, int param2, long @Nullable [] param3, long @Nullable [] param4, long @Nullable [] param5, long @Nullable [] param6, long __functionAddress);
    public static native void callPPPPPV(long param0, int param1, long @Nullable [] param2, int param3, int param4, int param5, long param6, int param7, long param8, int param9, long param10, long __functionAddress);
    public static native void callPPPPPPPV(int param0, int param1, int param2, long param3, int param4, long param5, int @Nullable [] param6, int @Nullable [] param7, int @Nullable [] param8, int @Nullable [] param9, long @Nullable [] param10, long __functionAddress);
    public static native boolean callPPZ(int param0, int @Nullable [] param1, long param2, long __functionAddress);
    public static native boolean callPPPPZ(int param0, int param1, int param2, float param3, float @Nullable [] param4, float @Nullable [] param5, float @Nullable [] param6, float @Nullable [] param7, long __functionAddress);

}
